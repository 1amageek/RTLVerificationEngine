import Foundation
import RTLVerificationCore
import ToolQualification

public struct ExternalRTLVerificationOracleExecutor: RTLVerificationOracleExecuting, Sendable {
    public var engine: ExternalRTLVerificationEngine

    public init(engine: ExternalRTLVerificationEngine) {
        self.engine = engine
    }

    public init(
        descriptor: RTLExternalToolDescriptor,
        trustDecision: ToolTrustDecision,
        runner: any RTLExternalToolProcessRunning = FoundationRTLExternalToolProcessRunner(),
        artifactReader: any RTLArtifactReading = InMemoryRTLArtifactReader(artifacts: [:]),
        additionalArguments: [String] = []
    ) {
        self.init(engine: ExternalRTLVerificationEngine(
            descriptor: descriptor,
            trustDecision: trustDecision,
            runner: runner,
            artifactReader: artifactReader,
            additionalArguments: additionalArguments
        ))
    }

    public func execute(
        _ request: RTLVerificationRequest,
        native: RTLVerificationResult
    ) async throws -> RTLVerificationResult {
        let oracle = try await engine.execute(request)
        guard let nativeRequestDigest = native.payload.requestDigest else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Native oracle correlation result is missing its request digest."
            )
        }
        guard oracle.payload.requestDigest == nativeRequestDigest else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Oracle result request digest does not match the native result."
            )
        }
        guard (oracle.provenance.producer.build ?? oracle.provenance.producer.identifier)
            != (native.provenance.producer.build ?? native.provenance.producer.identifier) else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Oracle result implementation must be independent from the native implementation."
            )
        }
        return oracle
    }
}
