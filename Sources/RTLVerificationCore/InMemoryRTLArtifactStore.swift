import CircuiteFoundation
import Foundation

public actor InMemoryRTLArtifactStore: RTLArtifactWriting {
    private var artifacts: [String: Data] = [:]
    public let namespace: RTLArtifactNamespace

    public init(
        namespace: RTLArtifactNamespace = .rtlVerification
    ) {
        self.namespace = namespace
    }

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> ArtifactReference {
        let runSegment = try RTLArtifactPathSegment(validating: runID)
        let artifactSegment = try RTLArtifactPathSegment(validating: artifactID)
        let path = "\(namespace.relativePath)/\(runSegment.rawValue)/\(artifactSegment.rawValue).json"
        if let existingData = artifacts[path] {
            throw existingData == data
                ? RTLArtifactStoreError.duplicateArtifact(path)
                : RTLArtifactStoreError.conflictingArtifact(path)
        }
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

    public func data(for reference: ArtifactReference) -> Data? {
        artifacts[reference.path]
    }
}
