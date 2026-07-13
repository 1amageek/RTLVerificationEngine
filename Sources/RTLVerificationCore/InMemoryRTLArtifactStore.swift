import CircuiteFoundation
import Foundation

public actor InMemoryRTLArtifactStore: RTLArtifactWriting {
    private var artifacts: [String: Data] = [:]

    public init() {}

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> RTLArtifactReference {
        let path = ".xcircuite/runs/\(runID)/\(artifactID).json"
        artifacts[path] = data
        return ArtifactReference(
            id: try ArtifactID(rawValue: artifactID),
            locator: ArtifactLocator(
                location: try ArtifactLocation(workspaceRelativePath: path),
                role: .output,
                kind: .report,
                format: .json
            ),
            digest: try SHA256ContentDigester().digest(data: data),
            byteCount: UInt64(data.count)
        )
    }

    public func data(for reference: RTLArtifactReference) -> Data? {
        artifacts[reference.path]
    }
}
