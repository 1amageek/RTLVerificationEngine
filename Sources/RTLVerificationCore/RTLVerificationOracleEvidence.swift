import CircuiteFoundation
import Foundation

public struct RTLVerificationOracleEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var evidenceID: String
    public var caseID: String
    public var requestDigest: String
    public var nativePayloadRequestDigest: String?
    public var oraclePayloadRequestDigest: String?
    public var nativeArtifact: RTLArtifactBinding
    public var oracleArtifact: RTLArtifactBinding
    public var report: RTLVerificationOracleCorrelationReport
    public var oracleProvenance: String
    public var recordedAt: Date

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case evidenceID
        case caseID
        case requestDigest
        case nativePayloadRequestDigest
        case oraclePayloadRequestDigest
        case nativeArtifact
        case oracleArtifact
        case report
        case oracleProvenance
        case recordedAt
    }

    public init(
        evidenceID: String,
        caseID: String,
        requestDigest: String,
        nativePayloadRequestDigest: String? = nil,
        oraclePayloadRequestDigest: String? = nil,
        nativeArtifact: RTLArtifactBinding,
        oracleArtifact: RTLArtifactBinding,
        report: RTLVerificationOracleCorrelationReport,
        oracleProvenance: String,
        recordedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationOracleEvidence.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceID = evidenceID
        self.caseID = caseID
        self.requestDigest = requestDigest
        self.nativePayloadRequestDigest = nativePayloadRequestDigest
        self.oraclePayloadRequestDigest = oraclePayloadRequestDigest
        self.nativeArtifact = nativeArtifact
        self.oracleArtifact = oracleArtifact
        self.report = report
        self.oracleProvenance = oracleProvenance
        self.recordedAt = recordedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL oracle evidence schema version \(schemaVersion)."
            )
        }
        self.init(
            evidenceID: try container.decode(String.self, forKey: .evidenceID),
            caseID: try container.decode(String.self, forKey: .caseID),
            requestDigest: try container.decode(String.self, forKey: .requestDigest),
            nativePayloadRequestDigest: try container.decodeIfPresent(
                String.self,
                forKey: .nativePayloadRequestDigest
            ),
            oraclePayloadRequestDigest: try container.decodeIfPresent(
                String.self,
                forKey: .oraclePayloadRequestDigest
            ),
            nativeArtifact: try container.decode(RTLArtifactBinding.self, forKey: .nativeArtifact),
            oracleArtifact: try container.decode(RTLArtifactBinding.self, forKey: .oracleArtifact),
            report: try container.decode(RTLVerificationOracleCorrelationReport.self, forKey: .report),
            oracleProvenance: try container.decode(String.self, forKey: .oracleProvenance),
            recordedAt: try container.decode(Date.self, forKey: .recordedAt),
            schemaVersion: schemaVersion
        )
    }

    public var artifactIDs: [String] {
        [nativeArtifact.logicalID, oracleArtifact.logicalID]
    }

    public var isAuditable: Bool {
        schemaVersion == Self.currentSchemaVersion
            && !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !caseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !requestDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nativePayloadRequestDigest == requestDigest
            && oraclePayloadRequestDigest == requestDigest
            && !oracleProvenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nativeArtifact.isDigestBound
            && oracleArtifact.isDigestBound
            && report.schemaVersion == RTLVerificationOracleCorrelationReport.currentSchemaVersion
            && report.caseID == caseID
            && report.matched
            && report.independenceVerified
            && report.nativeImplementationID != report.oracleImplementationID
    }
}

private extension RTLArtifactBinding {
    var isDigestBound: Bool {
        guard reference.digest.algorithm == .sha256,
              !reference.digest.hexadecimalValue.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              reference.byteCount > 0 else {
            return false
        }
        return !sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
