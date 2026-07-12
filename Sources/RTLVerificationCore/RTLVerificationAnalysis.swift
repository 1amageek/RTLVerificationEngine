import Foundation

public enum RTLVerificationAnalysis: String, Sendable, Hashable, Codable, CaseIterable {
    case lint
    case cdc
    case rdc
    case formalEquivalence

    public var stageID: String {
        switch self {
        case .lint:
            return "rtl.lint"
        case .cdc:
            return "rtl.cdc"
        case .rdc:
            return "rtl.rdc"
        case .formalEquivalence:
            return "rtl.equivalence"
        }
    }
}
