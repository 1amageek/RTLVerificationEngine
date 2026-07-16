import CircuiteFoundation
import Foundation

public struct RTLVerificationOracleEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceID: String
    public var caseID: String
    public var requestDigest: String
    public var nativePayloadRequestDigest: String?
    public var oraclePayloadRequestDigest: String?
    public var nativeArtifact: ArtifactReference
    public var oracleArtifact: ArtifactReference
    public var report: RTLVerificationOracleCorrelationReport
    public var oracleProvenance: String
    public var recordedAt: Date

    public init(
        evidenceID: String,
        caseID: String,
        requestDigest: String,
        nativePayloadRequestDigest: String? = nil,
        oraclePayloadRequestDigest: String? = nil,
        nativeArtifact: ArtifactReference,
        oracleArtifact: ArtifactReference,
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

    public var artifactIDs: [String] {
        [nativeArtifact.artifactID, oracleArtifact.artifactID].compactMap { $0 }
    }

    public var isAuditable: Bool {
        !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !caseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !requestDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nativePayloadRequestDigest == requestDigest
            && oraclePayloadRequestDigest == requestDigest
            && !oracleProvenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nativeArtifact.isDigestBound
            && oracleArtifact.isDigestBound
            && report.caseID == caseID
            && report.matched
            && report.independenceVerified
            && report.nativeImplementationID != report.oracleImplementationID
    }
}

private extension ArtifactReference {
    var isDigestBound: Bool {
        guard digest.algorithm == .sha256,
              !digest.hexadecimalValue.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              byteCount > 0 else {
            return false
        }
        return !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
