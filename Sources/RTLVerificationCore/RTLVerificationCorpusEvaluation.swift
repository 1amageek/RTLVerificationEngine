import Foundation
import XcircuitePackage

public struct RTLVerificationCorpusEvaluation: Sendable, Hashable, Codable {
    public var caseID: String
    public var matched: Bool
    public var observedStatus: XcircuiteEngineExecutionStatus
    public var observedFindingCodes: [String]
    public var mismatches: [RTLVerificationCorpusMismatch]

    public init(
        caseID: String,
        matched: Bool,
        observedStatus: XcircuiteEngineExecutionStatus,
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
