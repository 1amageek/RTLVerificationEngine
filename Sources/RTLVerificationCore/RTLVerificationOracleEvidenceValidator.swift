import Foundation

public struct RTLVerificationOracleEvidenceValidator: Sendable {
    public init() {}

    public func validate(
        _ evidence: RTLVerificationOracleEvidence,
        expectedRequestDigest: String? = nil
    ) throws {
        guard evidence.isAuditable else {
            throw RTLVerificationOracleEvidenceValidationError.notAuditable
        }
        guard evidence.report.caseID == evidence.caseID else {
            throw RTLVerificationOracleEvidenceValidationError.caseMismatch(
                expected: evidence.caseID,
                observed: evidence.report.caseID
            )
        }
        if let expectedRequestDigest,
           evidence.requestDigest != expectedRequestDigest {
            throw RTLVerificationOracleEvidenceValidationError.requestDigestMismatch(
                expected: expectedRequestDigest,
                observed: evidence.requestDigest
            )
        }
        guard evidence.report.matched else {
            throw RTLVerificationOracleEvidenceValidationError.reportMismatch
        }
        guard evidence.report.independenceVerified,
              evidence.report.nativeImplementationID != evidence.report.oracleImplementationID else {
            throw RTLVerificationOracleEvidenceValidationError.oracleNotIndependent
        }
    }
}
