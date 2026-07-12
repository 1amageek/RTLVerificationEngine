import Foundation
import XcircuitePackage

public struct RTLVerificationReport: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var analysis: RTLVerificationAnalysis
    public var status: XcircuiteEngineExecutionStatus
    public var diagnostics: [XcircuiteEngineDiagnostic]
    public var payload: RTLVerificationPayload
    public var inputArtifacts: [XcircuiteFileReference]
    public var generatedAt: Date

    public init(
        schemaVersion: Int = 1,
        runID: String,
        analysis: RTLVerificationAnalysis,
        status: XcircuiteEngineExecutionStatus,
        diagnostics: [XcircuiteEngineDiagnostic],
        payload: RTLVerificationPayload,
        inputArtifacts: [XcircuiteFileReference],
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
