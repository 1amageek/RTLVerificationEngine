import Foundation
import XcircuitePackage
import RTLVerificationCore

public protocol FormalEquivalenceChecking: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload>
}
