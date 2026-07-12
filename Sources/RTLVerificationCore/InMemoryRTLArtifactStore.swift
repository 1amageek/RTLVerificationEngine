import Foundation
import XcircuitePackage

public actor InMemoryRTLArtifactStore: RTLArtifactWriting {
    private var artifacts: [String: Data] = [:]

    public init() {}

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> XcircuiteFileReference {
        let path = ".xcircuite/runs/\(runID)/\(artifactID).json"
        artifacts[path] = data
        return XcircuiteFileReference(
            artifactID: artifactID,
            path: path,
            kind: .report,
            format: .json,
            sha256: XcircuiteHasher().sha256(data: data),
            byteCount: Int64(data.count),
            producedByRunID: runID
        )
    }

    public func data(for reference: XcircuiteFileReference) -> Data? {
        artifacts[reference.path]
    }
}
