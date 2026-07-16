import CircuiteFoundation
import Foundation

public actor FileSystemRTLArtifactStore: RTLArtifactWriting {
    public let artifactRoot: URL
    public let namespace: RTLArtifactNamespace

    public init(
        artifactRoot: URL,
        namespace: RTLArtifactNamespace
    ) throws {
        let standardizedRoot = artifactRoot.standardizedFileURL
        if FileManager.default.fileExists(atPath: standardizedRoot.path(percentEncoded: false)) {
            let values = try standardizedRoot.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw RTLArtifactStoreError.rootIsSymbolicLink(
                    standardizedRoot.path(percentEncoded: false)
                )
            }
        }
        self.artifactRoot = standardizedRoot.resolvingSymlinksInPath()
        self.namespace = namespace
    }

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> ArtifactReference {
        try prepareArtifactRoot()
        let runSegment = try RTLArtifactPathSegment(validating: runID)
        let artifactSegment = try RTLArtifactPathSegment(validating: artifactID)
        let relativePath = "\(namespace.relativePath)/\(runSegment.rawValue)/\(artifactSegment.rawValue).json"
        let fileURL = artifactRoot.appending(path: relativePath).standardizedFileURL
        try validateContainment(fileURL)
        try rejectSymbolicLinks(through: fileURL)

        let directoryURL = fileURL.deletingLastPathComponent()
        do {
            try validateArtifactRoot()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try validateArtifactRoot()
            try rejectSymbolicLinks(through: directoryURL)
            if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                let collision = try collisionError(
                    at: fileURL,
                    proposedData: data,
                    relativePath: relativePath
                )
                throw collision
            }
            try writeImmutable(data, to: fileURL, relativePath: relativePath)
        } catch let error as RTLArtifactStoreError {
            throw error
        } catch {
            if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                let collision = try collisionError(
                    at: fileURL,
                    proposedData: data,
                    relativePath: relativePath
                )
                throw collision
            }
            throw RTLArtifactStoreError.persistenceFailed(
                path: relativePath,
                reason: error.localizedDescription
            )
        }

        return ArtifactReference(
            id: try ArtifactID(rawValue: artifactID),
            locator: ArtifactLocator(
                location: try ArtifactLocation(workspaceRelativePath: relativePath),
                role: .output,
                kind: .report,
                format: .json
            ),
            digest: try SHA256ContentDigester().digest(data: data),
            byteCount: UInt64(data.count)
        )
    }

    private func prepareArtifactRoot() throws {
        let rootPath = artifactRoot.path(percentEncoded: false)
        if !FileManager.default.fileExists(atPath: rootPath) {
            try FileManager.default.createDirectory(
                at: artifactRoot,
                withIntermediateDirectories: true
            )
        }
        try validateArtifactRoot()
    }

    private func validateArtifactRoot() throws {
        let rootPath = artifactRoot.path(percentEncoded: false)
        let values = try artifactRoot.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw RTLArtifactStoreError.rootIsSymbolicLink(rootPath)
        }
        guard values.isDirectory == true else {
            throw RTLArtifactStoreError.rootIsNotDirectory(rootPath)
        }
    }

    private func validateContainment(_ url: URL) throws {
        let rootPath = artifactRoot.path(percentEncoded: false)
        let candidatePath = url.path(percentEncoded: false)
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard candidatePath.hasPrefix(rootPrefix) else {
            throw RTLArtifactStoreError.pathEscapesRoot(candidatePath)
        }
    }

    private func rejectSymbolicLinks(through url: URL) throws {
        var candidate = artifactRoot
        let rootComponents = artifactRoot.pathComponents
        let candidateComponents = url.pathComponents
        guard candidateComponents.starts(with: rootComponents) else {
            throw RTLArtifactStoreError.pathEscapesRoot(url.path(percentEncoded: false))
        }
        for component in candidateComponents.dropFirst(rootComponents.count) {
            candidate.append(path: component)
            guard FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) else {
                continue
            }
            let values = try candidate.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw RTLArtifactStoreError.symbolicLinkInPath(
                    candidate.path(percentEncoded: false)
                )
            }
        }
    }

    private func collisionError(
        at url: URL,
        proposedData: Data,
        relativePath: String
    ) throws -> RTLArtifactStoreError {
        let existingData: Data
        do {
            existingData = try Data(contentsOf: url)
        } catch {
            throw RTLArtifactStoreError.persistenceFailed(
                path: relativePath,
                reason: error.localizedDescription
            )
        }
        return existingData == proposedData
            ? .duplicateArtifact(relativePath)
            : .conflictingArtifact(relativePath)
    }

    private func writeImmutable(
        _ data: Data,
        to destinationURL: URL,
        relativePath: String
    ) throws {
        let temporaryURL = destinationURL.deletingLastPathComponent().appending(
            path: ".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        do {
            try data.write(to: temporaryURL, options: .atomic)
            try validateArtifactRoot()
            try rejectSymbolicLinks(through: destinationURL.deletingLastPathComponent())
            try FileManager.default.linkItem(at: temporaryURL, to: destinationURL)
        } catch {
            let originalError = error
            if FileManager.default.fileExists(atPath: temporaryURL.path(percentEncoded: false)) {
                do {
                    try FileManager.default.removeItem(at: temporaryURL)
                } catch {
                    throw RTLArtifactStoreError.persistenceFailed(
                        path: relativePath,
                        reason: "Temporary artifact cleanup failed: \(error.localizedDescription)"
                    )
                }
            }
            if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                throw try collisionError(
                    at: destinationURL,
                    proposedData: data,
                    relativePath: relativePath
                )
            }
            throw RTLArtifactStoreError.persistenceFailed(
                path: relativePath,
                reason: originalError.localizedDescription
            )
        }
        do {
            try FileManager.default.removeItem(at: temporaryURL)
        } catch {
            throw RTLArtifactStoreError.persistenceFailed(
                path: relativePath,
                reason: "Temporary artifact cleanup failed: \(error.localizedDescription)"
            )
        }
    }
}
