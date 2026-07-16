import Foundation

public enum RTLVerificationEvidenceRecordKind: String, Sendable, Hashable, Codable, CaseIterable {
    case smoke
    case healthCheck
    case corpus
    case oracleCorrelation
}
