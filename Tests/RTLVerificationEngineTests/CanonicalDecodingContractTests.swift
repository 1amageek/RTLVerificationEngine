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

        let unsupportedSchema = try replacingValue(2, forKey: "schemaVersion", in: data)
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
        let reference = makeTestArtifactReference(
            path: "rtl/top.sv",
            kind: .rtl,
            format: .systemVerilog
        )
        return RTLVerificationRequest(
            runID: "canonical-request",
            inputs: [reference],
            design: LogicDesignReference(
                artifact: reference,
                topDesignName: "top",
                designDigest: "design-digest"
            )
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
