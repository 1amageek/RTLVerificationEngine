import Foundation
import RTLVerificationCore

public protocol FormalEquivalenceChecking: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> RTLVerificationResult
}
