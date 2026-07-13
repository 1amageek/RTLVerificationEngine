import Foundation

public struct RTLVerificationReport: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var analysis: RTLVerificationAnalysis
    public var status: RTLExecutionStatus
    public var diagnostics: [RTLDiagnostic]
    public var payload: RTLVerificationPayload
    public var inputArtifacts: [RTLArtifactReference]
    public var generatedAt: Date

    public init(
        schemaVersion: Int = 1,
        runID: String,
        analysis: RTLVerificationAnalysis,
        status: RTLExecutionStatus,
        diagnostics: [RTLDiagnostic],
        payload: RTLVerificationPayload,
        inputArtifacts: [RTLArtifactReference],
        generatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.analysis = analysis
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
        self.inputArtifacts = inputArtifacts
        self.generatedAt = generatedAt
    }
}
