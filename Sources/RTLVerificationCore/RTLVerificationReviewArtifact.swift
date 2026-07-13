import Foundation

public struct RTLVerificationReviewArtifact: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var stageID: String
    public var runID: String
    public var analysis: RTLVerificationAnalysis
    public var status: RTLExecutionStatus
    public var findings: [RTLVerificationFinding]
    public var diagnostics: [RTLDiagnostic]
    public var appliedWaivers: [RTLVerificationWaiver]
    public var qualification: RTLVerificationQualificationReport
    public var approvalRequired: Bool
    public var suggestedActions: [String]
    public var generatedAt: Date

    public init(
        stageID: String,
        runID: String,
        analysis: RTLVerificationAnalysis,
        status: RTLExecutionStatus,
        findings: [RTLVerificationFinding],
        diagnostics: [RTLDiagnostic],
        appliedWaivers: [RTLVerificationWaiver],
        qualification: RTLVerificationQualificationReport,
        approvalRequired: Bool,
        suggestedActions: [String] = [],
        generatedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationReviewArtifact.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.stageID = stageID
        self.runID = runID
        self.analysis = analysis
        self.status = status
        self.findings = findings
        self.diagnostics = diagnostics
        self.appliedWaivers = appliedWaivers
        self.qualification = qualification
        self.approvalRequired = approvalRequired
        self.suggestedActions = suggestedActions
        self.generatedAt = generatedAt
    }
}
