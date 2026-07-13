import Foundation
import RTLVerificationCore

public protocol RTLLintExecuting: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> RTLVerificationResult
}
