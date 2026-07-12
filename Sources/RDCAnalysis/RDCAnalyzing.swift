import Foundation
import XcircuitePackage
import RTLVerificationCore

public protocol RDCAnalyzing: Sendable {
    func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload>
}
