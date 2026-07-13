import Foundation

public protocol RTLVerificationOracleEvidenceBuilding: Sendable {
    func build(
        caseID: String,
        requestDigest: String,
        native: RTLVerificationResult,
        oracle: RTLVerificationResult,
        oracleProvenance: String,
        runID: String
    ) async throws -> RTLVerificationOracleEvidenceBuildResult
}
