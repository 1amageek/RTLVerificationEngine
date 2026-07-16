import CircuiteFoundation
import Foundation
import LogicIR
import RTLLint
import Testing
import RTLVerificationCore
import RTLVerificationEngine

@Suite("RTL verification corpus runner")
struct CorpusRunnerTests {
    @Test("runner persists per-case results and an auditable summary", .timeLimit(.minutes(1)))
    func runnerPersistsResultsAndSummary() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let data = Data(source.utf8)
        let input = makeTestArtifactReference(
            artifactID: "rtl-input",
            path: "top.sv",
            kind: .rtl,
            format: .systemVerilog,
            sha256: SHA256ContentDigester().sha256(data: data),
            byteCount: Int64(data.count)
        )
        let reader = InMemoryRTLArtifactReader(artifacts: [input.locator.path: data])
        let writer = InMemoryRTLArtifactStore()
        let request = RTLVerificationRequest(
            runID: "unused",
            inputs: [input],
            design: LogicDesignReference(
                artifact: input,
                topDesignName: "top",
                designDigest: input.digest.hexadecimalValue
            ),
            analysis: .lint
        )
        let corpusCase = RTLVerificationCorpusCase(
            caseID: "positive-lint",
            request: request,
            expectation: RTLVerificationCorpusExpectation(status: .completed)
        )
        let runner = RTLVerificationCorpusRunner(
            engine: RTLVerificationEngine(environment: RTLVerificationEnvironment(reader: reader, writer: writer)),
            writer: writer
        )

        let run = try await runner.run([corpusCase], runID: "corpus-regression")

        #expect(run.matched)
        #expect(run.evaluations.count == 1)
        #expect(run.resultArtifacts["positive-lint"]?.artifactID == "corpus-positive-lint-result")
        #expect(run.resultArtifacts["positive-lint"]?.path.contains("corpus-regression") == true)
        #expect(run.resultArtifacts["positive-lint"]?.isDigestBound == true)
        #expect(run.summaryArtifact?.isDigestBound == true)
        #expect(await writer.data(for: run.resultArtifacts["positive-lint"]!) != nil)
        #expect(await writer.data(for: run.summaryArtifact!) != nil)
    }

    @Test("runner rejects duplicate case IDs before execution")
    func runnerRejectsDuplicateCaseIDs() async throws {
        let input = makeTestArtifactReference(
            artifactID: "rtl-input",
            path: "top.sv",
            kind: .rtl,
            format: .systemVerilog
        )
        let request = RTLVerificationRequest(
            runID: "unused",
            inputs: [input],
            design: LogicDesignReference(artifact: input, topDesignName: "top", designDigest: "digest")
        )
        let corpusCase = RTLVerificationCorpusCase(
            caseID: "duplicate",
            request: request,
            expectation: RTLVerificationCorpusExpectation(status: .completed)
        )
        let runner = RTLVerificationCorpusRunner(
            engine: RTLVerificationEngine(environment: RTLVerificationEnvironment(
                reader: InMemoryRTLArtifactReader(artifacts: [:])
            )),
            writer: InMemoryRTLArtifactStore()
        )

        await #expect(throws: RTLVerificationExecutionError.self) {
            try await runner.run([corpusCase, corpusCase], runID: "corpus-regression")
        }
    }
}

private extension ArtifactReference {
    var isDigestBound: Bool {
        !digest.hexadecimalValue.isEmpty && !locator.path.isEmpty
    }
}
