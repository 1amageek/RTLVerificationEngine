import CircuiteFoundation
import Foundation

public struct RTLVerificationProcessEvidenceBuildRequest: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var evidenceSetID: String
    public var requestDigest: String
    public var scope: RTLVerificationProcessEvidenceScope
    public var corpusEvidence: [RTLVerificationEvidenceRecord]
    public var oracleEvidence: [RTLVerificationOracleEvidence]
    public var healthEvidence: [RTLVerificationEvidenceRecord]
    public var artifacts: [ArtifactReference]
    public var provenance: String
    public var recordedAt: Date
    public var validUntil: Date

    public init(
        evidenceSetID: String,
        requestDigest: String,
        scope: RTLVerificationProcessEvidenceScope,
        corpusEvidence: [RTLVerificationEvidenceRecord],
        oracleEvidence: [RTLVerificationOracleEvidence],
        healthEvidence: [RTLVerificationEvidenceRecord],
        artifacts: [ArtifactReference],
        provenance: String,
        recordedAt: Date,
        validUntil: Date,
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.evidenceSetID = evidenceSetID
        self.requestDigest = requestDigest
        self.scope = scope
        self.corpusEvidence = corpusEvidence
        self.oracleEvidence = oracleEvidence
        self.healthEvidence = healthEvidence
        self.artifacts = artifacts
        self.provenance = provenance
        self.recordedAt = recordedAt
        self.validUntil = validUntil
    }
}
