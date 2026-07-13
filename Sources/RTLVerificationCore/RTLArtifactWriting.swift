import Foundation

public protocol RTLArtifactWriting: Sendable {
    func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> RTLArtifactReference
}
