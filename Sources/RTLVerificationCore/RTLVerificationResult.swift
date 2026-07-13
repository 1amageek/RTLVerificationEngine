import Foundation

/// RTL verification domain result. This type owns status, diagnostics and
/// payload for RTL analyses without a generic cross-domain result.
public struct RTLVerificationResult: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var status: RTLExecutionStatus
    public var diagnostics: [RTLDiagnostic]
    public var artifacts: [RTLArtifactReference]
    public var metadata: RTLExecutionMetadata
    public var payload: RTLVerificationPayload

    public init(
        schemaVersion: Int,
        runID: String,
        status: RTLExecutionStatus,
        diagnostics: [RTLDiagnostic] = [],
        artifacts: [RTLArtifactReference] = [],
        metadata: RTLExecutionMetadata,
        payload: RTLVerificationPayload
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.diagnostics = diagnostics
        self.artifacts = artifacts
        self.metadata = metadata
        self.payload = payload
    }
}
