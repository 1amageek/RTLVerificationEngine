import Foundation

public protocol RTLVerificationOracleExecuting: Sendable {
    func execute(
        _ request: RTLVerificationRequest,
        native: RTLVerificationResult
    ) async throws -> RTLVerificationResult
}
