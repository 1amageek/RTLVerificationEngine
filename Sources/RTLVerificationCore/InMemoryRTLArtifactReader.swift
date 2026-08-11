import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation

public struct InMemoryRTLArtifactReader: RTLArtifactReading {
    public var artifacts: [ArtifactID: Data]

    public init(artifacts: [ArtifactID: Data] = [:]) {
        self.artifacts = artifacts
    }

    public init(bindings: [RTLArtifactBinding], dataByLogicalID: [String: Data]) {
        self.artifacts = Dictionary(
            uniqueKeysWithValues: bindings.compactMap { binding in
                dataByLogicalID[binding.logicalID].map { (binding.reference.id, $0) }
            }
        )
    }

    public func read(_ binding: RTLArtifactBinding) async throws -> Data {
        guard let data = artifacts[binding.reference.id] else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: binding.sourcePath,
                reason: "The in-memory artifact is not registered."
            )
        }
        let observedDigest = try SHA256ContentDigester().digest(data: data, using: .sha256)
        guard observedDigest == binding.reference.digest else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: binding.sourcePath,
                reason: "The in-memory artifact digest does not match its reference."
            )
        }
        guard UInt64(data.count) == binding.reference.byteCount else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: binding.sourcePath,
                reason: "The in-memory artifact byte count does not match its reference."
            )
        }
        return data
    }
}
