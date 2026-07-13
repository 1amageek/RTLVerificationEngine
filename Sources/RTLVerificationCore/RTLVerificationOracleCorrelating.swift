import Foundation

public protocol RTLVerificationOracleCorrelating: Sendable {
    func correlate(
        caseID: String,
        native: RTLVerificationResult,
        oracle: RTLVerificationResult
    ) -> RTLVerificationOracleCorrelationReport
}
