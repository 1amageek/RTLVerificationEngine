import Foundation
import CircuiteFoundation

public struct InMemoryRTLArtifactReader: RTLArtifactReading {
    public var artifacts: [String: Data]

    public init(artifacts: [String: Data]) {
        self.artifacts = artifacts
    }

    public func read(_ reference: ArtifactReference) throws -> Data {
        guard let data = artifacts[reference.path] else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: "The in-memory artifact is not registered."
            )
        }
        let observedDigest = try SHA256ContentDigester().digest(data: data, using: .sha256)
        guard observedDigest == reference.digest else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: "The in-memory artifact digest does not match its reference."
            )
        }
        guard UInt64(data.count) == reference.byteCount else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: "The in-memory artifact byte count does not match its reference."
            )
        }
        return data
    }

    public func read(_ locator: ArtifactLocator) throws -> Data {
        guard let data = artifacts[locator.path] else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: locator.path,
                reason: "The in-memory artifact is not registered."
            )
        }
        return data
    }
}
