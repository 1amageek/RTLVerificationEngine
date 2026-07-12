import Foundation
import XcircuitePackage

public protocol RTLArtifactWriting: Sendable {
    func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> XcircuiteFileReference
}
