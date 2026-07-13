import Foundation
import RTLVerificationCore

public protocol CDCAnalyzing: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> RTLVerificationResult
}
