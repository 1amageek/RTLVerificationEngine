import Foundation
import XcircuitePackage

public struct RTLVerificationOracleEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceID: String
    public var caseID: String
    public var requestDigest: String
    public var nativeArtifact: XcircuiteFileReference
    public var oracleArtifact: XcircuiteFileReference
    public var report: RTLVerificationOracleCorrelationReport
    public var oracleProvenance: String
    public var recordedAt: Date

    public init(
        evidenceID: String,
        caseID: String,
        requestDigest: String,
        nativeArtifact: XcircuiteFileReference,
        oracleArtifact: XcircuiteFileReference,
        report: RTLVerificationOracleCorrelationReport,
        oracleProvenance: String,
        recordedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationOracleEvidence.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceID = evidenceID
        self.caseID = caseID
        self.requestDigest = requestDigest
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
            && !oracleProvenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nativeArtifact.isDigestBound
            && oracleArtifact.isDigestBound
            && report.caseID == caseID
            && report.matched
            && report.independenceVerified
            && report.nativeImplementationID != report.oracleImplementationID
    }
}

private extension XcircuiteFileReference {
    var isDigestBound: Bool {
        guard let sha256, !sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let byteCount, byteCount >= 0 else {
            return false
        }
        return !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
