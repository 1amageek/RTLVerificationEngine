import Foundation

public enum RTLVerificationEvidenceMaturity: String, Sendable, Hashable, Codable, CaseIterable, Comparable {
    case unassessed
    case smokeObserved
    case corpusObserved
    case oracleCorrelated

    public static func < (
        lhs: RTLVerificationEvidenceMaturity,
        rhs: RTLVerificationEvidenceMaturity
    ) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .unassessed: 0
        case .smokeObserved: 1
        case .corpusObserved: 2
        case .oracleCorrelated: 3
        }
    }
}
