import Foundation

public struct RTLVerificationCorpusExpectation: Sendable, Hashable, Codable {
    public var status: RTLExecutionStatus
    public var requiredFindingCodes: [String]
    public var forbiddenFindingCodes: [String]
    public var proofStatus: String?
    public var minimumAnalyzedFraction: Double?

    public init(
        status: RTLExecutionStatus,
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
