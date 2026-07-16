import CircuiteFoundation
import Foundation
import LogicIR
import Testing
import RTLVerificationCore
import RTLLint

@Suite("RTL verification observation input")
struct EvidenceInputTests {
    @Test("artifact-bound observations are applied without release authority", .timeLimit(.minutes(1)))
    func evidenceInputIsApplied() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let rtl = makeTestArtifactReference(
            artifactID: "rtl-input",
            path: "top.sv",
            kind: .rtl,
            format: .systemVerilog,
            sha256: SHA256ContentDigester().sha256(data: Data(source.utf8)),
            byteCount: Int64(source.utf8.count)
        )
        let reader = InMemoryRTLArtifactReader(artifacts: [rtl.path: Data(source.utf8)])
        let now = Date()
        let caseID = "lint-positive"
        let oracleReport = RTLVerificationOracleCorrelationReport(
            caseID: caseID,
            nativeImplementationID: "native-rtl-verification",
            oracleImplementationID: "independent-oracle",
            nativeImplementationVersion: "1.0.0",
            oracleImplementationVersion: "oracle-1",
            independenceVerified: true,
            matched: true,
            checkedAt: now
        )
        var oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle:\(caseID)",
            caseID: caseID,
            requestDigest: "request-digest",
            nativePayloadRequestDigest: "request-digest",
            oraclePayloadRequestDigest: "request-digest",
            nativeArtifact: jsonReference(
                artifactID: "native-result",
                path: "native.json",
                data: Data("native".utf8)
            ),
            oracleArtifact: jsonReference(
                artifactID: "oracle-result",
                path: "oracle.json",
                data: Data("oracle".utf8)
            ),
            report: oracleReport,
            oracleProvenance: "retained-independent-oracle",
            recordedAt: now
        )
        var evidenceInput = RTLVerificationEvidenceInput(
            corpusEvaluations: [RTLVerificationCorpusEvaluation(
                caseID: caseID,
                matched: true,
                observedStatus: .completed,
                observedFindingCodes: [],
                mismatches: []
            )],
            oracleReports: [oracleReport],
            oracleEvidence: [oracleEvidence],
            expectedRequestDigest: nil
        )
        var request = RTLVerificationRequest(
            runID: "record-input",
            inputs: [rtl],
            design: LogicDesignReference(
                artifact: rtl,
                topDesignName: "top",
                designDigest: rtl.sha256
            ),
            analysis: .lint,
            evidenceInput: evidenceInput
        )
        let requestDigest = try RTLVerificationRequestDigest.make(request)
        oracleEvidence.requestDigest = requestDigest
        oracleEvidence.nativePayloadRequestDigest = requestDigest
        oracleEvidence.oraclePayloadRequestDigest = requestDigest
        evidenceInput.oracleEvidence = [oracleEvidence]
        evidenceInput.expectedRequestDigest = requestDigest
        request.evidenceInput = evidenceInput

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.record.maturity == .oracleCorrelated)
        #expect(envelope.payload.record.evidence.map(\.kind) == [.corpus, .oracleCorrelation])
        #expect(envelope.payload.record.limitations.isEmpty)

        evidenceInput.expectedRequestDigest = "another-request-digest"
        request.evidenceInput = evidenceInput
        let mismatchedEnvelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(mismatchedEnvelope.status == .completed)
        #expect(mismatchedEnvelope.payload.record.maturity == .corpusObserved)
        #expect(mismatchedEnvelope.payload.record.evidence.map(\.kind) == [.corpus])
    }

    private func jsonReference(artifactID: String, path: String, data: Data) -> ArtifactReference {
        makeTestArtifactReference(
            artifactID: artifactID,
            path: path,
            kind: .report,
            format: .json,
            sha256: SHA256ContentDigester().sha256(data: data),
            byteCount: Int64(data.count)
        )
    }
}
