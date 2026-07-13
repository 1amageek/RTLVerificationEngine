import Foundation
import CircuiteFoundation

public struct FileSystemRTLArtifactStore: RTLArtifactWriting {
    public var projectRoot: URL

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
    }

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> RTLArtifactReference {
        let safeArtifactID = artifactID.replacingOccurrences(of: "/", with: "-")
        let relativePath = ".xcircuite/runs/\(runID)/\(safeArtifactID).json"
        let url = projectRoot.appending(path: relativePath)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            let location = try ArtifactLocation(fileURL: url)
            return ArtifactReference(
                id: try ArtifactID(rawValue: artifactID),
                locator: ArtifactLocator(
                    location: location,
                    role: .output,
                    kind: .report,
                    format: .json
                ),
                digest: try SHA256ContentDigester().digest(data: data),
                byteCount: UInt64(data.count)
            )
        } catch {
            throw RTLVerificationExecutionError.artifactWriteFailed(
                artifactID: artifactID,
                reason: error.localizedDescription
            )
        }
    }
}
