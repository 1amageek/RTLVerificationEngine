import Foundation

public struct RTLVerificationStageAuditRecord: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var stageID: String
    public var runID: String
    public var requestDigest: String
    public var status: RTLExecutionStatus
    public var qualificationState: RTLVerificationQualificationState
    public var artifactIDs: [String]
    public var resumable: Bool
    public var nextActions: [String]
    public var generatedAt: Date

    public init(
        stageID: String,
        runID: String,
        requestDigest: String,
        status: RTLExecutionStatus,
        qualificationState: RTLVerificationQualificationState,
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
        self.qualificationState = qualificationState
        self.artifactIDs = artifactIDs.sorted()
        self.resumable = resumable
        self.nextActions = nextActions
        self.generatedAt = generatedAt
    }
}
