import Foundation
import XcircuitePackage

public protocol RTLVerificationExecuting: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload>
}
