import Foundation

public struct RTLVerificationOracleCorrelationReport: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var caseID: String
    public var nativeImplementationID: String
    public var oracleImplementationID: String
    public var nativeImplementationVersion: String
    public var oracleImplementationVersion: String
    public var independenceVerified: Bool
    public var matched: Bool
    public var mismatches: [RTLVerificationOracleCorrelationMismatch]
    public var checkedAt: Date

    public init(
        caseID: String,
        nativeImplementationID: String,
        oracleImplementationID: String,
        nativeImplementationVersion: String,
        oracleImplementationVersion: String,
        independenceVerified: Bool,
        matched: Bool,
        mismatches: [RTLVerificationOracleCorrelationMismatch] = [],
        checkedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationOracleCorrelationReport.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.caseID = caseID
        self.nativeImplementationID = nativeImplementationID
        self.oracleImplementationID = oracleImplementationID
        self.nativeImplementationVersion = nativeImplementationVersion
        self.oracleImplementationVersion = oracleImplementationVersion
        self.independenceVerified = independenceVerified
        self.matched = matched
        self.mismatches = mismatches
        self.checkedAt = checkedAt
    }

    public func qualificationEvidence(
        evidenceID: String,
        artifactIDs: [String] = [],
        scopeID: String? = nil
    ) -> RTLVerificationQualificationEvidence? {
        guard matched, independenceVerified, !artifactIDs.isEmpty else { return nil }
        return RTLVerificationQualificationEvidence(
            evidenceID: evidenceID,
            kind: .oracleCorrelation,
            artifactIDs: artifactIDs,
            scopeID: scopeID,
            summary: "Native implementation \(nativeImplementationID) correlated with independent oracle \(oracleImplementationID) for corpus case \(caseID).",
            checkedAt: checkedAt
        )
    }
}
