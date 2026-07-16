import Foundation

public struct RTLVerificationStageAuditRecord: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var stageID: String
    public var runID: String
    public var requestDigest: String
    public var status: RTLExecutionStatus
    public var evidenceMaturity: RTLVerificationEvidenceMaturity
    public var artifactIDs: [String]
    public var resumable: Bool
    public var nextActions: [String]
    public var generatedAt: Date

    public init(
        stageID: String,
        runID: String,
        requestDigest: String,
        status: RTLExecutionStatus,
        evidenceMaturity: RTLVerificationEvidenceMaturity,
        artifactIDs: [String],
        resumable: Bool,
        nextActions: [String] = [],
        generatedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationStageAuditRecord.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.stageID = stageID
        self.runID = runID
        self.requestDigest = requestDigest
        self.status = status
        self.evidenceMaturity = evidenceMaturity
        self.artifactIDs = artifactIDs.sorted()
        self.resumable = resumable
        self.nextActions = nextActions
        self.generatedAt = generatedAt
    }
}
