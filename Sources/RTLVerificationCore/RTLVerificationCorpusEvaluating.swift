import Foundation
import XcircuitePackage

public protocol RTLVerificationCorpusEvaluating: Sendable {
    func evaluate(
        _ corpusCase: RTLVerificationCorpusCase,
        result: XcircuiteEngineResultEnvelope<RTLVerificationPayload>
    ) -> RTLVerificationCorpusEvaluation
}
