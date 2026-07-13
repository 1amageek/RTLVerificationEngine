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
    func resultProjectsDigestBoundArtifactsAndDiagnostics() throws {
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
            metadata: RTLExecutionMetadata(
                engineID: "rtl.lint",
                implementationID: "native-rtl-verification",
                implementationVersion: "1.0.0",
                startedAt: Date(timeIntervalSinceReferenceDate: 0),
                completedAt: Date(timeIntervalSinceReferenceDate: 1)
            ),
            payload: RTLVerificationPayload(findingCount: 1)
        )
        let provenance = try ExecutionProvenance(
            producer: ProducerIdentity(
                kind: .engine,
                identifier: "native-rtl-verification",
                version: "1.0.0"
            ),
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            completedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        let projection = try RTLVerificationFoundationEvidence(
            result: envelope,
            provenance: provenance
        )

        #expect(projection.evidence.artifacts.count == 1)
        #expect(projection.evidence.artifacts[0].digest.hexadecimalValue == digest)
        #expect(projection.diagnostics.count == 1)
        #expect(projection.diagnostics[0].severity == .error)
        #expect(projection.diagnostics[0].subject?.identifier == "top.u1")
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
            metadata: RTLExecutionMetadata(
                engineID: "rtl.lint",
                implementationID: "native-rtl-verification",
                implementationVersion: "1.0.0",
                startedAt: Date(timeIntervalSinceReferenceDate: 0),
                completedAt: Date(timeIntervalSinceReferenceDate: 1)
            ),
            payload: RTLVerificationPayload(findingCount: 0)
        )
        let provenance = try ExecutionProvenance(
            producer: ProducerIdentity(
                kind: .engine,
                identifier: "native-rtl-verification",
                version: "1.0.0"
            ),
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            completedAt: Date(timeIntervalSinceReferenceDate: 1)
        )

        let projection = try RTLVerificationFoundationEvidence(
            result: envelope,
            provenance: provenance
        )
        #expect(projection.artifacts.count == 1)
        #expect(projection.artifacts[0].digest.algorithm == .sha256)
    }

    private struct MockRTLVerificationEngine: RTLVerificationExecuting {
        func execute(
            _ request: RTLVerificationRequest
        ) async throws -> RTLVerificationResult {
            fatalError("The protocol conformance is compile-time evidence only.")
        }
    }
}
