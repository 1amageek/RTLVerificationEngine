import Foundation
import XcircuitePackage

public struct RTLVerificationProcessQualificationEvidenceBuildRequest: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var qualificationID: String
    public var requestDigest: String
    public var scope: RTLVerificationProcessQualificationScope
    public var corpusEvidence: [RTLVerificationQualificationEvidence]
    public var oracleEvidence: [RTLVerificationOracleEvidence]
    public var healthEvidence: [RTLVerificationQualificationEvidence]
    public var artifacts: [XcircuiteFileReference]
    public var provenance: String
    public var qualifiedAt: Date
    public var expiresAt: Date

    public init(
        qualificationID: String,
        requestDigest: String,
        scope: RTLVerificationProcessQualificationScope,
        corpusEvidence: [RTLVerificationQualificationEvidence],
        oracleEvidence: [RTLVerificationOracleEvidence],
        healthEvidence: [RTLVerificationQualificationEvidence],
        artifacts: [XcircuiteFileReference],
        provenance: String,
        qualifiedAt: Date,
        expiresAt: Date,
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.qualificationID = qualificationID
        self.requestDigest = requestDigest
        self.scope = scope
        self.corpusEvidence = corpusEvidence
        self.oracleEvidence = oracleEvidence
        self.healthEvidence = healthEvidence
        self.artifacts = artifacts
        self.provenance = provenance
        self.qualifiedAt = qualifiedAt
        self.expiresAt = expiresAt
    }
}
