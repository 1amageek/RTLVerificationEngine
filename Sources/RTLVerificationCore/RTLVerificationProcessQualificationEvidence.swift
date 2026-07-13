import Foundation

public struct RTLVerificationProcessQualificationEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceID: String
    public var qualificationID: String
    public var qualification: RTLVerificationProcessQualificationRecord
    public var artifactIDs: [String]
    public var provenance: String
    public var recordedAt: Date

    public init(
        evidenceID: String,
        qualificationID: String,
        qualification: RTLVerificationProcessQualificationRecord,
        artifactIDs: [String],
        provenance: String,
        recordedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationProcessQualificationEvidence.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceID = evidenceID
        self.qualificationID = qualificationID
        self.qualification = qualification
        self.artifactIDs = artifactIDs.sorted()
        self.provenance = provenance
        self.recordedAt = recordedAt
    }

    public var isAuditable: Bool {
        !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && qualificationID == qualification.qualificationID
            && !artifactIDs.isEmpty
            && artifactIDs.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            && !provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && qualification.isQualified(at: recordedAt)
    }

    public func matches(
        _ record: RTLVerificationProcessQualificationRecord,
        at date: Date
    ) -> Bool {
        isAuditable
            && qualification == record
            && qualification.isQualified(at: date)
    }
}
