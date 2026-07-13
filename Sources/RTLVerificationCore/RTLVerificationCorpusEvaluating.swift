import Foundation

public protocol RTLVerificationCorpusEvaluating: Sendable {
    func evaluate(
        _ corpusCase: RTLVerificationCorpusCase,
        result: RTLVerificationResult
    ) -> RTLVerificationCorpusEvaluation
}
