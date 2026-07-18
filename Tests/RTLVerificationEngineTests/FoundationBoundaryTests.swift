import CircuiteFoundation
import Foundation
import RTLVerificationCore
import Testing

@Suite
struct FoundationBoundaryTests {
    @Test
    func engineProtocolUsesFoundationEngineContract() {
        func accepts(_ engine: any Engine) {}
        accepts(MockRTLVerificationEngine())
    }

    @Test
    func resultExposesDigestBoundArtifactsAndDiagnostics() throws {
        let data = Data("rtl report".utf8)
        let digest = SHA256ContentDigester().sha256(data: data)
        let artifact = makeTestArtifactReference(
            artifactID: "rtl-report",
            path: "reports/rtl.json",
            kind: .report,
            format: .json,
            sha256: digest,
            byteCount: Int64(data.count)
        )
        let envelope = RTLVerificationResult(
            schemaVersion: 1,
            runID: "run-1",
            status: .blocked,
            diagnostics: [
                RTLDiagnostic(
                    severity: .error,
                    code: "RTL_UNSUPPORTED_SEMANTICS",
                    message: "Unsupported RTL construct.",
                    entity: "top.u1"
                )
            ],
            artifacts: [artifact],
            provenance: try makeRTLTestProvenance(
                engineID: "rtl.lint",
                implementationID: "native-rtl-verification",
                implementationVersion: "1.0.0",
                startedAt: Date(timeIntervalSinceReferenceDate: 0),
                completedAt: Date(timeIntervalSinceReferenceDate: 1)
            ),
            payload: RTLVerificationPayload(findingCount: 1)
        )
        #expect(envelope.evidence.artifacts.count == 1)
        #expect(envelope.evidence.artifacts[0].digest.hexadecimalValue == digest)
        #expect(envelope.diagnostics.count == 1)
        #expect(envelope.diagnostics[0].severity == .error)
        #expect(envelope.diagnostics[0].subject?.identifier == "top.u1")
        let evidenceID = envelope.evidence.id
        #expect(envelope.evidence.id == evidenceID)
        let decoded = try JSONDecoder().decode(
            RTLVerificationResult.self,
            from: JSONEncoder().encode(envelope)
        )
        #expect(decoded.evidence.id == evidenceID)
    }

    @Test
    func resultAcceptsCanonicalArtifactIntegrityMetadata() throws {
        let envelope = RTLVerificationResult(
            schemaVersion: 1,
            runID: "run-1",
            status: .completed,
            artifacts: [
                makeTestArtifactReference(
                    artifactID: "rtl-report",
                    path: "reports/rtl.json",
                    kind: .report,
                    format: .json
                )
            ],
            provenance: try makeRTLTestProvenance(
                engineID: "rtl.lint",
                implementationID: "native-rtl-verification",
                implementationVersion: "1.0.0",
                startedAt: Date(timeIntervalSinceReferenceDate: 0),
                completedAt: Date(timeIntervalSinceReferenceDate: 1)
            ),
            payload: RTLVerificationPayload(findingCount: 0)
        )
        #expect(envelope.artifacts.count == 1)
        #expect(envelope.artifacts[0].digest.algorithm == .sha256)
    }

    @Test
    func resultStructuresInvalidDiagnosticCode() throws {
        let result = RTLVerificationResult(
            schemaVersion: 1,
            runID: "run-invalid-code",
            status: .blocked,
            diagnostics: [
                RTLDiagnostic(
                    severity: .error,
                    code: " invalid-code",
                    message: "The producer emitted an invalid code."
                ),
            ],
            provenance: try makeRTLTestProvenance(
                engineID: "rtl.lint",
                implementationID: "native-rtl-verification",
                implementationVersion: "1.0.0",
                startedAt: Date(timeIntervalSinceReferenceDate: 0),
                completedAt: Date(timeIntervalSinceReferenceDate: 1)
            ),
            payload: RTLVerificationPayload(findingCount: 1)
        )

        #expect(result.diagnostics.first?.code.rawValue == "rtl.invalid-diagnostic-code")
        #expect(result.diagnostics.first?.detail?.contains(" invalid-code") == true)
    }

    private struct MockRTLVerificationEngine: RTLVerificationExecuting {
        func execute(
            _ request: RTLVerificationRequest
        ) async throws -> RTLVerificationResult {
            fatalError("The protocol conformance is compile-time evidence only.")
        }
    }
}
