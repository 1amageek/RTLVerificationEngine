import Foundation
import XcircuitePackage

public struct RTLVerificationCorpusEvaluator: RTLVerificationCorpusEvaluating {
    public init() {}

    public func evaluate(
        _ corpusCase: RTLVerificationCorpusCase,
        result: XcircuiteEngineResultEnvelope<RTLVerificationPayload>
    ) -> RTLVerificationCorpusEvaluation {
        let expectation = corpusCase.expectation
        var mismatches: [RTLVerificationCorpusMismatch] = []
        if result.status != expectation.status {
            mismatches.append(RTLVerificationCorpusMismatch(
                code: "CORPUS_STATUS_MISMATCH",
                message: "Expected status \(expectation.status.rawValue), observed \(result.status.rawValue)."
            ))
        }

        let observedCodes = Set(result.payload.findings.map(\.code))
        for code in expectation.requiredFindingCodes where !observedCodes.contains(code) {
            mismatches.append(RTLVerificationCorpusMismatch(
                code: "CORPUS_REQUIRED_FINDING_MISSING",
                message: "Required finding code \(code) was not observed."
            ))
        }
        for code in expectation.forbiddenFindingCodes where observedCodes.contains(code) {
            mismatches.append(RTLVerificationCorpusMismatch(
                code: "CORPUS_FORBIDDEN_FINDING_OBSERVED",
                message: "Forbidden finding code \(code) was observed."
            ))
        }
        if let expectedProofStatus = expectation.proofStatus,
           result.payload.proofStatus != expectedProofStatus {
            mismatches.append(RTLVerificationCorpusMismatch(
                code: "CORPUS_PROOF_STATUS_MISMATCH",
                message: "Expected proof status \(expectedProofStatus), observed \(result.payload.proofStatus ?? "nil")."
            ))
        }
        if let minimumAnalyzedFraction = expectation.minimumAnalyzedFraction,
           result.payload.coverage.analyzedFraction < minimumAnalyzedFraction {
            mismatches.append(RTLVerificationCorpusMismatch(
                code: "CORPUS_COVERAGE_INSUFFICIENT",
                message: "Analyzed fraction is below the expected corpus threshold."
            ))
        }

        return RTLVerificationCorpusEvaluation(
            caseID: corpusCase.caseID,
            matched: mismatches.isEmpty,
            observedStatus: result.status,
            observedFindingCodes: Array(observedCodes),
            mismatches: mismatches
        )
    }
}
