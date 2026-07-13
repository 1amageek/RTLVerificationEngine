import Foundation
import XcircuitePackage

public struct RTLVerificationProcessQualificationEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceID: String
    public var qualificationID: String
    public var qualification: RTLVerificationProcessQualificationRecord
    public var artifactIDs: [String]
    public var artifacts: [XcircuiteFileReference]
    public var provenance: String
    public var recordedAt: Date

    public init(
        evidenceID: String,
        qualificationID: String,
        qualification: RTLVerificationProcessQualificationRecord,
        artifactIDs: [String],
        artifacts: [XcircuiteFileReference] = [],
        provenance: String,
        recordedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationProcessQualificationEvidence.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceID = evidenceID
        self.qualificationID = qualificationID
        self.qualification = qualification
        self.artifactIDs = artifactIDs.sorted()
        self.artifacts = artifacts
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
            && Set(artifactIDs).count == artifactIDs.count
            && artifactIDs == artifacts.compactMap(\.artifactID).sorted()
            && artifacts.allSatisfy(Self.isDigestBound)
            && !provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && qualification.isQualified(at: recordedAt)
    }

    private static func isDigestBound(_ artifact: XcircuiteFileReference) -> Bool {
        guard let artifactID = artifact.artifactID,
              !artifactID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifact.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifact.path.hasPrefix("/"),
              !artifact.path.split(separator: "/").contains(".."),
              let sha256 = artifact.sha256,
              sha256.count == 64,
              sha256.allSatisfy(\.isHexDigit),
              let byteCount = artifact.byteCount,
              byteCount >= 0 else {
            return false
        }
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case evidenceID
        case qualificationID
        case qualification
        case artifactIDs
        case artifacts
        case provenance
        case recordedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.evidenceID = try container.decode(String.self, forKey: .evidenceID)
        self.qualificationID = try container.decode(String.self, forKey: .qualificationID)
        self.qualification = try container.decode(
            RTLVerificationProcessQualificationRecord.self,
            forKey: .qualification
        )
        self.artifactIDs = try container.decode([String].self, forKey: .artifactIDs)
        self.artifacts = try container.decodeIfPresent(
            [XcircuiteFileReference].self,
            forKey: .artifacts
        ) ?? []
        self.provenance = try container.decode(String.self, forKey: .provenance)
        self.recordedAt = try container.decode(Date.self, forKey: .recordedAt)
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
