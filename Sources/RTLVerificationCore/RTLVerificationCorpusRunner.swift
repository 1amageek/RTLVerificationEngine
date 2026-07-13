import Foundation
import XcircuitePackage

public struct RTLVerificationCorpusRunner: RTLVerificationCorpusRunning {
    public let engine: any RTLVerificationExecuting
    public let evaluator: any RTLVerificationCorpusEvaluating
    public let writer: any RTLArtifactWriting

    public init(
        engine: any RTLVerificationExecuting,
        evaluator: any RTLVerificationCorpusEvaluating = RTLVerificationCorpusEvaluator(),
        writer: any RTLArtifactWriting
    ) {
        self.engine = engine
        self.evaluator = evaluator
        self.writer = writer
    }

    public func run(
        _ corpus: [RTLVerificationCorpusCase],
        runID: String
    ) async throws -> RTLVerificationCorpusRun {
        guard !runID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest("Corpus run ID must not be empty.")
        }
        guard !corpus.isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest("Corpus must contain at least one case.")
        }

        let caseIDs = corpus.map(\.caseID)
        guard Set(caseIDs).count == caseIDs.count else {
            throw RTLVerificationExecutionError.invalidRequest("Corpus case IDs must be unique.")
        }
        guard caseIDs.allSatisfy(Self.isSafeIdentifier) else {
            throw RTLVerificationExecutionError.invalidRequest(
                "Corpus case IDs must contain only letters, numbers, '.', '_' or '-'."
            )
        }

        var evaluations: [RTLVerificationCorpusEvaluation] = []
        var resultArtifacts: [String: XcircuiteFileReference] = [:]
        for corpusCase in corpus.sorted(by: { $0.caseID < $1.caseID }) {
            var request = corpusCase.request
            request.runID = "\(runID)-\(corpusCase.caseID)"
            let result = try await engine.execute(request)
            let resultData = try Self.encode(result)
            let resultArtifact = try await writer.persist(
                resultData,
                artifactID: "corpus-\(corpusCase.caseID)-result",
                runID: runID
            )
            resultArtifacts[corpusCase.caseID] = resultArtifact
            evaluations.append(evaluator.evaluate(corpusCase, result: result))
        }

        var run = RTLVerificationCorpusRun(
            runID: runID,
            evaluations: evaluations,
            resultArtifacts: resultArtifacts
        )
        let summaryArtifact = try await writer.persist(
            try Self.encode(run),
            artifactID: "corpus-run",
            runID: runID
        )
        run.summaryArtifact = summaryArtifact
        return run
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "." || character == "_" || character == "-"
        }
    }
}
