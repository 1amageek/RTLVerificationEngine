import CircuiteFoundation
import Foundation

/// Creates verified Foundation references for files in an RTL workspace.
public struct RTLArtifactReferenceBuilder: Sendable {
    public init() {}

    public func reference(
        forProjectRelativePath path: String,
        artifactID: String,
        kind: ArtifactKind,
        format: ArtifactFormat,
        inProjectAt projectRoot: URL
    ) throws -> ArtifactReference {
        let root = projectRoot.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = URL(filePath: path, relativeTo: root)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path == root.path || candidate.path.hasPrefix(rootPath) else {
            throw RTLVerificationExecutionError.invalidRequest(
                "Artifact path escapes project root: \(path)"
            )
        }
        let locator = ArtifactLocator(
            location: try ArtifactLocation(fileURL: candidate),
            role: .input,
            kind: kind,
            format: format
        )
        return try LocalArtifactReferencer().reference(locator, producer: nil)
            .withID(try ArtifactID(rawValue: artifactID))
    }

    public func readJSON<T: Decodable>(
        _ type: T.Type,
        named path: String,
        forProjectAt projectRoot: URL
    ) throws -> T {
        let locator = try reference(
            forProjectRelativePath: path,
            artifactID: "rtl-input-\(path.hashValue)",
            kind: .constraints,
            format: .json,
            inProjectAt: projectRoot
        )
        let url = try locator.locator.location.resolvedFileURL()
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

private extension ArtifactReference {
    func withID(_ id: ArtifactID) -> ArtifactReference {
        ArtifactReference(
            id: id,
            locator: locator,
            digest: digest,
            byteCount: byteCount,
            producer: producer
        )
    }
}
