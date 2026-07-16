import Foundation

public struct RTLVerificationProcessEvidenceRecord: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceSetID: String
    public var scope: RTLVerificationProcessEvidenceScope
    public var status: RTLVerificationProcessEvidenceStatus
    public var corpusEvidenceIDs: [String]
    public var oracleEvidenceIDs: [String]
    public var healthEvidenceIDs: [String]
    public var blockers: [String]
    public var recordedAt: Date?
    public var validUntil: Date?

    public init(
        evidenceSetID: String,
        scope: RTLVerificationProcessEvidenceScope,
        status: RTLVerificationProcessEvidenceStatus = .incomplete,
        corpusEvidenceIDs: [String] = [],
        oracleEvidenceIDs: [String] = [],
        healthEvidenceIDs: [String] = [],
        blockers: [String] = [],
        recordedAt: Date? = nil,
        validUntil: Date? = nil,
        schemaVersion: Int = RTLVerificationProcessEvidenceRecord.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceSetID = evidenceSetID
        self.scope = scope
        self.status = status
        self.corpusEvidenceIDs = corpusEvidenceIDs.sorted()
        self.oracleEvidenceIDs = oracleEvidenceIDs.sorted()
        self.healthEvidenceIDs = healthEvidenceIDs.sorted()
        self.blockers = blockers.sorted()
        self.recordedAt = recordedAt
        self.validUntil = validUntil
    }

    public var isComplete: Bool {
        isComplete(at: Date())
    }

    public func isComplete(at date: Date) -> Bool {
        status == .complete
            && scope.isComplete
            && !corpusEvidenceIDs.isEmpty
            && !oracleEvidenceIDs.isEmpty
            && !healthEvidenceIDs.isEmpty
            && blockers.isEmpty
            && isFresh(at: date)
    }

    public func isFresh(at date: Date) -> Bool {
        guard let recordedAt, let validUntil else { return false }
        return recordedAt <= date && date < validUntil
    }

    public func completed(
        at date: Date,
        corpusEvidenceIDs: [String],
        oracleEvidenceIDs: [String],
        healthEvidenceIDs: [String],
        validUntil: Date? = nil
    ) -> RTLVerificationProcessEvidenceRecord {
        RTLVerificationProcessEvidenceRecord(
            evidenceSetID: evidenceSetID,
            scope: scope,
            status: .complete,
            corpusEvidenceIDs: corpusEvidenceIDs,
            oracleEvidenceIDs: oracleEvidenceIDs,
            healthEvidenceIDs: healthEvidenceIDs,
            blockers: [],
            recordedAt: date,
            validUntil: validUntil,
            schemaVersion: schemaVersion
        )
    }
}
