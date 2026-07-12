import Foundation
import XcircuitePackage

public protocol RTLVerificationOracleCorrelating: Sendable {
    func correlate(
        caseID: String,
        native: XcircuiteEngineResultEnvelope<RTLVerificationPayload>,
        oracle: XcircuiteEngineResultEnvelope<RTLVerificationPayload>
    ) -> RTLVerificationOracleCorrelationReport
}
