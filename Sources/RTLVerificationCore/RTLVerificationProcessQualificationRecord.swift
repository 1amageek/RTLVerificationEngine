import Foundation

public struct RTLVerificationProcessQualificationRecord: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var qualificationID: String
    public var scope: RTLVerificationProcessQualificationScope
    public var status: RTLVerificationProcessQualificationStatus
    public var corpusEvidenceIDs: [String]
    public var oracleEvidenceIDs: [String]
    public var healthEvidenceIDs: [String]
    public var blockers: [String]
    public var qualifiedAt: Date?

    public init(
        qualificationID: String,
        scope: RTLVerificationProcessQualificationScope,
        status: RTLVerificationProcessQualificationStatus = .unqualified,
        corpusEvidenceIDs: [String] = [],
        oracleEvidenceIDs: [String] = [],
        healthEvidenceIDs: [String] = [],
        blockers: [String] = [],
        qualifiedAt: Date? = nil,
        schemaVersion: Int = RTLVerificationProcessQualificationRecord.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.qualificationID = qualificationID
        self.scope = scope
        self.status = status
        self.corpusEvidenceIDs = corpusEvidenceIDs.sorted()
        self.oracleEvidenceIDs = oracleEvidenceIDs.sorted()
        self.healthEvidenceIDs = healthEvidenceIDs.sorted()
        self.blockers = blockers.sorted()
        self.qualifiedAt = qualifiedAt
    }

    public var isQualified: Bool {
        status == .qualified
            && scope.isComplete
            && !corpusEvidenceIDs.isEmpty
            && !oracleEvidenceIDs.isEmpty
            && !healthEvidenceIDs.isEmpty
            && blockers.isEmpty
    }

    public func qualified(
        at date: Date,
        corpusEvidenceIDs: [String],
        oracleEvidenceIDs: [String],
        healthEvidenceIDs: [String]
    ) -> RTLVerificationProcessQualificationRecord {
        RTLVerificationProcessQualificationRecord(
            qualificationID: qualificationID,
            scope: scope,
            status: .qualified,
            corpusEvidenceIDs: corpusEvidenceIDs,
            oracleEvidenceIDs: oracleEvidenceIDs,
            healthEvidenceIDs: healthEvidenceIDs,
            blockers: [],
            qualifiedAt: date,
            schemaVersion: schemaVersion
        )
    }
}
