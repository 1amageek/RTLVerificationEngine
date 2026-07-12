import Foundation

public enum RTLVerificationQualificationState: String, Sendable, Hashable, Codable, CaseIterable, Comparable {
    case unassessed
    case smokeChecked
    case corpusChecked
    case oracleCorrelated
    case processQualified
    case releaseEligible

    public static func < (
        lhs: RTLVerificationQualificationState,
        rhs: RTLVerificationQualificationState
    ) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .unassessed: 0
        case .smokeChecked: 1
        case .corpusChecked: 2
        case .oracleCorrelated: 3
        case .processQualified: 4
        case .releaseEligible: 5
        }
    }
}
