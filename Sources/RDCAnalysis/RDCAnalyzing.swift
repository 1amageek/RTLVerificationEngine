import Foundation
import RTLVerificationCore

public protocol RDCAnalyzing: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> RTLVerificationResult
}
