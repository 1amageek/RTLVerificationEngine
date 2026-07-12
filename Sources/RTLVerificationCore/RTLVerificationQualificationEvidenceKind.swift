import Foundation

public enum RTLVerificationQualificationEvidenceKind: String, Sendable, Hashable, Codable, CaseIterable {
    case smoke
    case corpus
    case oracleCorrelation
    case processQualification
    case releaseApproval
}
