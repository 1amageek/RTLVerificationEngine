import Foundation
import XcircuitePackage

public struct FileSystemRTLArtifactStore: RTLArtifactWriting {
    public var projectRoot: URL
    private var packageStore: XcircuitePackageStore

    public init(projectRoot: URL, packageStore: XcircuitePackageStore = XcircuitePackageStore()) {
        self.projectRoot = projectRoot
        self.packageStore = packageStore
    }

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> XcircuiteFileReference {
        let safeArtifactID = artifactID.replacingOccurrences(of: "/", with: "-")
        let relativePath = ".xcircuite/runs/\(runID)/\(safeArtifactID).json"
        let url: URL
        do {
            url = try packageStore.url(forProjectRelativePath: relativePath, inProjectAt: projectRoot)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return try packageStore.fileReference(
                forProjectRelativePath: relativePath,
                artifactID: artifactID,
                kind: .report,
                format: .json,
                inProjectAt: projectRoot,
                producedByRunID: runID
            )
        } catch {
            throw RTLVerificationExecutionError.artifactWriteFailed(
                artifactID: artifactID,
                reason: error.localizedDescription
            )
        }
    }
}
