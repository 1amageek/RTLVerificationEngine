import CircuiteFoundation
import Foundation
import RTLVerificationCore
import Testing
import XcircuitePackage

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
        let digest = XcircuiteHasher().sha256(data: data)
        let artifact = XcircuiteFileReference(
            artifactID: "rtl-report",
            path: "reports/rtl.json",
            kind: .report,
            format: .json,
            sha256: digest,
            byteCount: Int64(data.count)
        )
        let envelope = XcircuiteEngineResultEnvelope(
            schemaVersion: 1,
            runID: "run-1",
            status: .blocked,
            diagnostics: [
                XcircuiteEngineDiagnostic(
                    severity: .error,
                    code: "RTL_UNSUPPORTED_SEMANTICS",
                    message: "Unsupported RTL construct.",
                    entity: "top.u1"
                )
            ],
            artifacts: [artifact],
            metadata: XcircuiteEngineExecutionMetadata(
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
            envelope: envelope,
            provenance: provenance
        )

        #expect(projection.evidence.artifacts.count == 1)
        #expect(projection.evidence.artifacts[0].digest.hexadecimalValue == digest)
        #expect(projection.diagnostics.count == 1)
        #expect(projection.diagnostics[0].severity == .error)
        #expect(projection.diagnostics[0].subject?.identifier == "top.u1")
    }

    @Test
    func resultRejectsArtifactsWithoutIntegrityMetadata() throws {
        let envelope = XcircuiteEngineResultEnvelope(
            schemaVersion: 1,
            runID: "run-1",
            status: .completed,
            artifacts: [
                XcircuiteFileReference(
                    artifactID: "rtl-report",
                    path: "reports/rtl.json",
                    kind: .report,
                    format: .json
                )
            ],
            metadata: XcircuiteEngineExecutionMetadata(
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

        #expect(throws: RTLVerificationFoundationBoundaryError.self) {
            try RTLVerificationFoundationEvidence(
                envelope: envelope,
                provenance: provenance
            )
        }
    }

    private struct MockRTLVerificationEngine: RTLVerificationExecuting {
        func execute(
            _ request: RTLVerificationRequest
        ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
            fatalError("The protocol conformance is compile-time evidence only.")
        }
    }
}
