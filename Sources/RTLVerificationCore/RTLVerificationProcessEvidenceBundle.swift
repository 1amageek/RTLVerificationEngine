import Foundation

public struct RTLVerificationProcessEvidenceBundle: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceID: String
    public var evidenceSetID: String
    public var record: RTLVerificationProcessEvidenceRecord
    public var artifactIDs: [String]
    public var artifacts: [RTLArtifactReference]
    public var provenance: String
    public var recordedAt: Date

    public init(
        evidenceID: String,
        evidenceSetID: String,
        record: RTLVerificationProcessEvidenceRecord,
        artifactIDs: [String],
        artifacts: [RTLArtifactReference] = [],
        provenance: String,
        recordedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationProcessEvidenceBundle.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceID = evidenceID
        self.evidenceSetID = evidenceSetID
        self.record = record
        self.artifactIDs = artifactIDs.sorted()
        self.artifacts = artifacts
        self.provenance = provenance
        self.recordedAt = recordedAt
    }

    public var isAuditable: Bool {
        !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && evidenceSetID == record.evidenceSetID
            && !artifactIDs.isEmpty
            && artifactIDs.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            && Set(artifactIDs).count == artifactIDs.count
            && artifactIDs == artifacts.map(\.artifactID).sorted()
            && artifacts.allSatisfy(Self.isDigestBound)
            && !provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && record.isComplete(at: recordedAt)
    }

    private static func isDigestBound(_ artifact: RTLArtifactReference) -> Bool {
        let artifactID = artifact.artifactID
        let sha256 = artifact.sha256
        guard !artifactID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifact.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifact.path.hasPrefix("/"),
              !artifact.path.split(separator: "/").contains(".."),
              artifact.digest.algorithm == .sha256,
              sha256.count == 64,
              sha256.allSatisfy(\.isHexDigit),
              artifact.byteCount >= 0 else {
            return false
        }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case evidenceID
        case evidenceSetID
        case record
        case artifactIDs
        case artifacts
        case provenance
        case recordedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL process evidence bundle schema version \(schemaVersion)."
            )
        }
        self.evidenceID = try container.decode(String.self, forKey: .evidenceID)
        self.evidenceSetID = try container.decode(String.self, forKey: .evidenceSetID)
        self.record = try container.decode(
            RTLVerificationProcessEvidenceRecord.self,
            forKey: .record
        )
        self.artifactIDs = try container.decode([String].self, forKey: .artifactIDs)
        self.artifacts = try container.decode(
            [RTLArtifactReference].self,
            forKey: .artifacts
        )
        self.provenance = try container.decode(String.self, forKey: .provenance)
        self.recordedAt = try container.decode(Date.self, forKey: .recordedAt)
    }

    public func matches(
        _ record: RTLVerificationProcessEvidenceRecord,
        at date: Date
    ) -> Bool {
        isAuditable
            && self.record == record
            && record.isComplete(at: date)
    }
}
