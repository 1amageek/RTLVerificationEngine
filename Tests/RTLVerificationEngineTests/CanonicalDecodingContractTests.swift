import Foundation
import FormalEquivalence
import LogicIR
import RTLVerificationCore
import Testing

@Suite("Canonical RTL verification decoding")
struct CanonicalDecodingContractTests {
    @Test("request requires its current schema version")
    func requestRequiresCurrentSchemaVersion() throws {
        let request = makeRequest()
        let data = try JSONEncoder().encode(request)

        let missingSchema = try removingKey("schemaVersion", from: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationRequest.self, from: missingSchema)
        }

        let unsupportedSchema = try replacingValue(99, forKey: "schemaVersion", in: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationRequest.self, from: unsupportedSchema)
        }
    }

    @Test("request requires nonoptional canonical fields")
    func requestRequiresCanonicalFields() throws {
        let data = try JSONEncoder().encode(makeRequest())
        let missingAnalysis = try removingKey("analysis", from: data)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationRequest.self, from: missingAnalysis)
        }

        let mismatchedInputs = try replacingValue([], forKey: "inputs", in: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationRequest.self, from: mismatchedInputs)
        }
    }

    @Test("result requires the current schema and content-addressed evidence identity")
    func resultRequiresCanonicalEvidence() throws {
        let result = try makeResult()
        let data = try JSONEncoder().encode(result)

        let unsupportedSchema = try replacingValue(99, forKey: "schemaVersion", in: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationResult.self, from: unsupportedSchema)
        }

        var object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var evidence = try #require(object["evidence"] as? [String: Any])
        evidence["id"] = String(repeating: "0", count: 32)
        object["evidence"] = evidence
        let mismatchedEvidence = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationResult.self, from: mismatchedEvidence)
        }
    }

    @Test("oracle evidence and corpus runs reject unsupported schemas")
    func retainedEvidenceRequiresCurrentSchemas() throws {
        let binding = makeTestArtifactBinding(
            artifactID: "observation",
            path: "evidence/observation.json",
            kind: .evidence,
            format: .json,
            data: Data("observation".utf8)
        )
        let report = RTLVerificationOracleCorrelationReport(
            caseID: "case-1",
            nativeImplementationID: "native",
            oracleImplementationID: "oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: true
        )
        let oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle-case-1",
            caseID: "case-1",
            requestDigest: "request-digest",
            nativePayloadRequestDigest: "request-digest",
            oraclePayloadRequestDigest: "request-digest",
            nativeArtifact: binding,
            oracleArtifact: binding,
            report: report,
            oracleProvenance: "independent-oracle"
        )
        let unsupportedOracle = try replacingValue(
            99,
            forKey: "schemaVersion",
            in: JSONEncoder().encode(oracleEvidence)
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationOracleEvidence.self, from: unsupportedOracle)
        }

        let corpusRun = RTLVerificationCorpusRun(
            runID: "corpus-run",
            evaluations: [],
            resultArtifacts: [:]
        )
        let unsupportedCorpus = try replacingValue(
            99,
            forKey: "schemaVersion",
            in: JSONEncoder().encode(corpusRun)
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationCorpusRun.self, from: unsupportedCorpus)
        }
    }

    @Test("evidence input requires its current schema version")
    func evidenceInputRequiresCurrentSchemaVersion() throws {
        let input = RTLVerificationEvidenceInput()
        let data = try JSONEncoder().encode(input)

        let missingSchema = try removingKey("schemaVersion", from: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationEvidenceInput.self, from: missingSchema)
        }

        let missingEvaluations = try removingKey("corpusEvaluations", from: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLVerificationEvidenceInput.self, from: missingEvaluations)
        }
    }

    @Test("formal counterexample requires its current schema version")
    func formalCounterexampleRequiresCurrentSchemaVersion() throws {
        let counterexample = RTLFormalCounterexample(
            runID: "formal-run",
            topModuleName: "top",
            mismatches: ["output mismatch"],
            affectedEntities: ["top.q"]
        )
        let data = try JSONEncoder().encode(counterexample)

        let missingSchema = try removingKey("schemaVersion", from: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLFormalCounterexample.self, from: missingSchema)
        }

        let unsupportedSchema = try replacingValue(2, forKey: "schemaVersion", in: data)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RTLFormalCounterexample.self, from: unsupportedSchema)
        }
    }

    private func makeRequest() -> RTLVerificationRequest {
        let binding = makeTestArtifactBinding(
            path: "rtl/top.sv",
            kind: .rtl,
            format: .systemVerilog
        )
        let reference = binding.reference
        return RTLVerificationRequest(
            runID: "canonical-request",
            inputBindings: [binding],
            design: LogicDesignReference(
                artifact: reference,
                topDesignName: "top",
                designDigest: "design-digest"
            )
        )
    }

    private func makeResult() throws -> RTLVerificationResult {
        let binding = makeTestArtifactBinding(
            artifactID: "report",
            path: "reports/result.json",
            kind: .report,
            format: .json,
            data: Data("result".utf8)
        )
        let now = Date(timeIntervalSince1970: 1)
        return try RTLVerificationResult(
            schemaVersion: RTLVerificationResult.currentSchemaVersion,
            runID: "canonical-result",
            status: .completed,
            artifactBindings: [binding],
            provenance: makeRTLTestProvenance(
                engineID: "rtl.lint",
                implementationID: "native-rtl-verification",
                implementationVersion: "1",
                startedAt: now,
                completedAt: now
            ),
            payload: RTLVerificationPayload(findingCount: 0)
        )
    }

    private func removingKey(_ key: String, from data: Data) throws -> Data {
        var object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: key)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func replacingValue(_ value: Any, forKey key: String, in data: Data) throws -> Data {
        var object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object[key] = value
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
