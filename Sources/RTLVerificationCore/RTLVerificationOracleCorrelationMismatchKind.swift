import Foundation

public enum RTLVerificationOracleCorrelationMismatchKind: String, Sendable, Hashable, Codable, CaseIterable {
    case oracleNotIndependent
    case status
    case analysis
    case findingCodes
    case proofStatus
    case proofView
    case semanticCoverage
    case sourceProvenance
}
