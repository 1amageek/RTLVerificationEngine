import Foundation
import XcircuitePackage

public struct RTLVerificationCorpusExpectation: Sendable, Hashable, Codable {
    public var status: XcircuiteEngineExecutionStatus
    public var requiredFindingCodes: [String]
    public var forbiddenFindingCodes: [String]
    public var proofStatus: String?
    public var minimumAnalyzedFraction: Double?

    public init(
        status: XcircuiteEngineExecutionStatus,
        requiredFindingCodes: [String] = [],
        forbiddenFindingCodes: [String] = [],
        proofStatus: String? = nil,
        minimumAnalyzedFraction: Double? = nil
    ) {
        self.status = status
        self.requiredFindingCodes = requiredFindingCodes.sorted()
        self.forbiddenFindingCodes = forbiddenFindingCodes.sorted()
        self.proofStatus = proofStatus
        self.minimumAnalyzedFraction = minimumAnalyzedFraction
    }
}
