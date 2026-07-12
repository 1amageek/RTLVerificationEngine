import Foundation
import XcircuitePackage
import RTLVerificationCore

public protocol CDCAnalyzing: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload>
}
