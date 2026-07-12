import Foundation

public struct RTLVerificationQualificationEvidence: Sendable, Hashable, Codable {
    public var evidenceID: String
    public var kind: RTLVerificationQualificationEvidenceKind
    public var artifactIDs: [String]
    public var scopeID: String?
    public var summary: String
    public var checkedAt: Date?

    public init(
        evidenceID: String,
        kind: RTLVerificationQualificationEvidenceKind,
        artifactIDs: [String] = [],
        scopeID: String? = nil,
        summary: String,
        checkedAt: Date? = nil
    ) {
        self.evidenceID = evidenceID
        self.kind = kind
        self.artifactIDs = artifactIDs
        self.scopeID = scopeID
        self.summary = summary
        self.checkedAt = checkedAt
    }

    public var isAuditable: Bool {
        !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!artifactIDs.isEmpty || !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
