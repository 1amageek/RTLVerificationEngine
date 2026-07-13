import Foundation
import Testing
import RTLVerificationCore

@Suite("RTL verification oracle evidence builder")
struct OracleEvidenceBuilderTests {
    @Test("builder persists independent oracle evidence with digest-bound artifacts", .timeLimit(.minutes(1)))
    func builderPersistsIndependentEvidence() async throws {
        let writer = InMemoryRTLArtifactStore()
        let native = envelope(implementationID: "native-rtl-verification", implementationVersion: "1.0.0")
        let oracle = envelope(implementationID: "independent-oracle", implementationVersion: "oracle-1")
        let builder = RTLVerificationOracleEvidenceBuilder(writer: writer)

        let result = try await builder.build(
            caseID: "lint-positive",
            requestDigest: "request-digest",
            native: native,
            oracle: oracle,
            oracleProvenance: "retained-independent-oracle",
            runID: "oracle-regression"
        )

        #expect(result.evidence.isAuditable)
        #expect(result.evidence.report.matched)
        #expect(result.nativeArtifact.artifactID == "oracle-lint-positive-native")
        #expect(result.oracleArtifact.artifactID == "oracle-lint-positive-result")
        #expect(result.evidenceArtifact.artifactID == "oracle-lint-positive-evidence")
        #expect(await writer.data(for: result.evidenceArtifact) != nil)
    }

    @Test("builder retains mismatched oracle correlation without producing qualification evidence")
    func builderRetainsMismatch() async throws {
        let writer = InMemoryRTLArtifactStore()
        let native = envelope(implementationID: "native-rtl-verification", implementationVersion: "1.0.0")
        let oracle = envelope(implementationID: "independent-oracle", implementationVersion: "oracle-1", findingCode: "ORACLE_ONLY")
        let builder = RTLVerificationOracleEvidenceBuilder(writer: writer)

        let result = try await builder.build(
            caseID: "lint-mismatch",
            requestDigest: "request-digest",
            native: native,
            oracle: oracle,
            oracleProvenance: "retained-independent-oracle",
            runID: "oracle-regression"
        )

        #expect(!result.evidence.isAuditable)
        #expect(!result.evidence.report.matched)
        #expect(result.evidence.report.mismatches.contains { $0.kind == .findingCodes })
        #expect(await writer.data(for: result.evidenceArtifact) != nil)
    }

    @Test("builder rejects an envelope whose payload belongs to another request")
    func builderRejectsPayloadRequestDigestMismatch() async throws {
        let writer = InMemoryRTLArtifactStore()
        var native = envelope(implementationID: "native-rtl-verification", implementationVersion: "1.0.0")
        native.payload.requestDigest = "other-request-digest"
        let oracle = envelope(implementationID: "independent-oracle", implementationVersion: "oracle-1")
        let builder = RTLVerificationOracleEvidenceBuilder(writer: writer)

        do {
            _ = try await builder.build(
                caseID: "lint-digest-mismatch",
                requestDigest: "request-digest",
                native: native,
                oracle: oracle,
                oracleProvenance: "retained-independent-oracle",
                runID: "oracle-regression"
            )
            Issue.record("Oracle evidence must reject a payload from another request.")
        } catch let error as RTLVerificationExecutionError {
            #expect(error == .invalidArtifact(
                "Native oracle evidence result request digest does not match the evidence request."
            ))
        }
    }

    private func envelope(
        implementationID: String,
        implementationVersion: String,
        findingCode: String? = nil
    ) -> RTLVerificationResult {
        let now = Date(timeIntervalSince1970: 1)
        let finding = findingCode.map {
            RTLVerificationFinding(
                severity: .error,
                code: $0,
                message: "Finding"
            )
        }
        return RTLVerificationResult(
            schemaVersion: 1,
            runID: "oracle-run",
            status: .completed,
            metadata: RTLExecutionMetadata(
                engineID: "rtl.test",
                implementationID: implementationID,
                implementationVersion: implementationVersion,
                startedAt: now,
                completedAt: now
            ),
            payload: RTLVerificationPayload(
                findingCount: finding == nil ? 0 : 1,
                requestDigest: "request-digest",
                analysis: .lint,
                findings: finding.map { [$0] } ?? [],
                coverage: RTLVerificationCoverage(totalConstructs: 1, analyzedConstructs: 1)
            )
        )
    }
}
