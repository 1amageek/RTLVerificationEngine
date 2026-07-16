import Foundation

public struct RTLVerificationEvidenceAssessment: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var implementationID: String
    public var implementationVersion: String
    public var maturity: RTLVerificationEvidenceMaturity
    public var evidence: [RTLVerificationEvidenceRecord]
    public var limitations: [String]
    public var checkedAt: Date?

    public init(
        implementationID: String = "native-rtl-verification",
        implementationVersion: String = "1.0.0",
        maturity: RTLVerificationEvidenceMaturity = .unassessed,
        evidence: [RTLVerificationEvidenceRecord] = [],
        limitations: [String] = [],
        checkedAt: Date? = nil,
        schemaVersion: Int = RTLVerificationEvidenceAssessment.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.implementationID = implementationID
        self.implementationVersion = implementationVersion
        self.maturity = maturity
        self.evidence = evidence
        self.limitations = limitations
        self.checkedAt = checkedAt
    }
}
