import Foundation

public struct RTLVerificationEvidenceRecord: Sendable, Hashable, Codable {
    public var evidenceID: String
    public var kind: RTLVerificationEvidenceRecordKind
    public var artifactIDs: [String]
    public var scopeID: String?
    public var implementationID: String?
    public var implementationVersion: String?
    public var summary: String
    public var checkedAt: Date?

    public init(
        evidenceID: String,
        kind: RTLVerificationEvidenceRecordKind,
        artifactIDs: [String] = [],
        scopeID: String? = nil,
        implementationID: String? = nil,
        implementationVersion: String? = nil,
        summary: String,
        checkedAt: Date? = nil
    ) {
        self.evidenceID = evidenceID
        self.kind = kind
        self.artifactIDs = artifactIDs
        self.scopeID = scopeID
        self.implementationID = implementationID
        self.implementationVersion = implementationVersion
        self.summary = summary
        self.checkedAt = checkedAt
    }

    public var isAuditable: Bool {
        guard !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifactIDs.isEmpty || !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard kind == .healthCheck else { return true }
        return hasImplementationIdentity
    }

    public var hasImplementationIdentity: Bool {
        guard let implementationID, let implementationVersion else { return false }
        return !implementationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !implementationVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func matchesImplementation(id: String, version: String) -> Bool {
        implementationID == id && implementationVersion == version
    }
}
