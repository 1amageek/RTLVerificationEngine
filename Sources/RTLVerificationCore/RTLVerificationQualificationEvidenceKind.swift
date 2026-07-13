import Foundation

public enum RTLVerificationQualificationEvidenceKind: String, Sendable, Hashable, Codable, CaseIterable {
    case smoke
    case healthCheck
    case corpus
    case oracleCorrelation
    case processQualification
    case releaseApproval
}
