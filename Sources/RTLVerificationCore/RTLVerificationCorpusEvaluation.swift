import Foundation

public struct RTLVerificationCorpusEvaluation: Sendable, Hashable, Codable {
    public var caseID: String
    public var matched: Bool
    public var observedStatus: RTLExecutionStatus
    public var observedFindingCodes: [String]
    public var mismatches: [RTLVerificationCorpusMismatch]

    public init(
        caseID: String,
        matched: Bool,
        observedStatus: RTLExecutionStatus,
        observedFindingCodes: [String],
        mismatches: [RTLVerificationCorpusMismatch]
    ) {
        self.caseID = caseID
        self.matched = matched
        self.observedStatus = observedStatus
        self.observedFindingCodes = observedFindingCodes.sorted()
        self.mismatches = mismatches
    }
}
