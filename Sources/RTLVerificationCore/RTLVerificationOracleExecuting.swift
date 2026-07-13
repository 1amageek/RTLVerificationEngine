import Foundation
import XcircuitePackage

public protocol RTLVerificationOracleExecuting: Sendable {
    func execute(
        _ request: RTLVerificationRequest,
        native: XcircuiteEngineResultEnvelope<RTLVerificationPayload>
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload>
}
