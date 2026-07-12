import Foundation
import XcircuitePackage

public struct InMemoryRTLArtifactReader: RTLArtifactReading {
    public var artifacts: [String: Data]

    public init(artifacts: [String: Data]) {
        self.artifacts = artifacts
    }

    public func read(_ reference: XcircuiteFileReference) throws -> Data {
        guard let data = artifacts[reference.path] else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: "The in-memory artifact is not registered."
            )
        }
        return data
    }
}
