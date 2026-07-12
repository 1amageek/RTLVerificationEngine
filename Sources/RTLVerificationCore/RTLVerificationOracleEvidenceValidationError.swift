import Foundation

public enum RTLVerificationOracleEvidenceValidationError: Error, Sendable, Hashable {
    case notAuditable
    case caseMismatch(expected: String, observed: String)
    case requestDigestMismatch(expected: String, observed: String)
    case reportMismatch
    case oracleNotIndependent
}

extension RTLVerificationOracleEvidenceValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuditable:
            return "Oracle evidence is missing a digest-bound artifact, provenance, or matched correlation report."
        case .caseMismatch(let expected, let observed):
            return "Oracle evidence case ID mismatch: expected \(expected), observed \(observed)."
        case .requestDigestMismatch(let expected, let observed):
            return "Oracle evidence request digest mismatch: expected \(expected), observed \(observed)."
        case .reportMismatch:
            return "Oracle correlation report is not matched."
        case .oracleNotIndependent:
            return "Oracle correlation does not prove independent implementations."
        }
    }
}
