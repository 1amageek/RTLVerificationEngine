import Foundation
import XcircuitePackage
import RTLVerificationCore

public protocol RTLLintExecuting: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload>
}
