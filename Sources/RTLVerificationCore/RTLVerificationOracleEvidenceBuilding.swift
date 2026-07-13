import Foundation
import XcircuitePackage

public protocol RTLVerificationOracleEvidenceBuilding: Sendable {
    func build(
        caseID: String,
        requestDigest: String,
        native: XcircuiteEngineResultEnvelope<RTLVerificationPayload>,
        oracle: XcircuiteEngineResultEnvelope<RTLVerificationPayload>,
        oracleProvenance: String,
        runID: String
    ) async throws -> RTLVerificationOracleEvidenceBuildResult
}
