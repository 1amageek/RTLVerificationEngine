import Foundation
import Testing
import RTLVerificationCore

@Suite("RTL process evidence builder")
struct ProcessEvidenceBuilderTests {
    @Test("builder creates auditable process evidence from retained artifacts")
    func buildsProcessEvidence() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let result = try RTLVerificationProcessEvidenceBuilder().build(
            makeRequest(),
            at: date
        )

        #expect(result.record.isComplete(at: date))
        #expect(result.evidence.isAuditable)
        #expect(result.evidence.matches(result.record, at: date))
        #expect(result.record.corpusEvidenceIDs == ["corpus:case-1"])
        #expect(result.record.oracleEvidenceIDs == ["oracle:case-1"])
        #expect(result.record.healthEvidenceIDs == ["health-1"])
    }

    @Test("builder rejects evidence that references a missing artifact")
    func rejectsMissingArtifact() throws {
        var request = makeRequest()
        request.artifacts.removeAll { $0.artifactID == "health" }

        do {
            _ = try RTLVerificationProcessEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("A process record must retain every referenced artifact.")
        } catch let error as RTLVerificationProcessEvidenceBuildError {
            #expect(error == .missingArtifact("health"))
        }
    }

    @Test("builder rejects an oracle with a different request digest")
    func rejectsOracleDigestMismatch() throws {
        var request = makeRequest()
        request.oracleEvidence[0].requestDigest = "different-request"

        do {
            _ = try RTLVerificationProcessEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("An oracle evidence artifact must bind to the evidence request.")
        } catch let error as RTLVerificationProcessEvidenceBuildError {
            #expect(error == .invalidEvidence("oracle-evidence:case-1"))
        }
    }

    @Test("builder rejects an unreferenced retained artifact")
    func rejectsUnreferencedArtifact() throws {
        var request = makeRequest()
        request.artifacts.append(artifact(id: "unreferenced", path: "extra.json", fill: "2"))

        do {
            _ = try RTLVerificationProcessEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("Every retained process record artifact must be referenced.")
        } catch let error as RTLVerificationProcessEvidenceBuildError {
            #expect(error == .invalidInput(
                "every retained artifact must be referenced by record evidence"
            ))
        }
    }

    @Test("builder rejects a validity window that is not current")
    func rejectsExpiredWindow() throws {
        var request = makeRequest()
        request.validUntil = Date(timeIntervalSince1970: 900)

        do {
            _ = try RTLVerificationProcessEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("Expired process record evidence must not be generated.")
        } catch let error as RTLVerificationProcessEvidenceBuildError {
            #expect(error == .invalidValidityWindow)
        }
    }

    private func makeRequest() -> RTLVerificationProcessEvidenceBuildRequest {
        let date = Date(timeIntervalSince1970: 900)
        let scope = RTLVerificationProcessEvidenceScope(
            implementationID: "impl",
            binaryDigest: String(repeating: "b", count: 64),
            algorithmVersion: "1",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: String(repeating: "c", count: 64),
            deckDigest: String(repeating: "d", count: 64),
            analyses: [.lint]
        )
        let report = RTLVerificationOracleCorrelationReport(
            caseID: "case-1",
            nativeImplementationID: "impl",
            oracleImplementationID: "oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: true,
            checkedAt: date
        )
        let oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle-evidence:case-1",
            caseID: "case-1",
            requestDigest: "request",
            nativePayloadRequestDigest: "request",
            oraclePayloadRequestDigest: "request",
            nativeArtifact: artifact(
                id: "native",
                path: "oracle/native.json",
                fill: "e"
            ),
            oracleArtifact: artifact(
                id: "oracle",
                path: "oracle/result.json",
                fill: "f"
            ),
            report: report,
            oracleProvenance: "tool:oracle@1",
            recordedAt: date
        )
        return RTLVerificationProcessEvidenceBuildRequest(
            evidenceSetID: "record-1",
            requestDigest: "request",
            scope: scope,
            corpusEvidence: [RTLVerificationEvidenceRecord(
                evidenceID: "corpus:case-1",
                kind: .corpus,
                artifactIDs: ["corpus"],
                scopeID: "case-1",
                summary: "Corpus case passed.",
                checkedAt: date
            )],
            oracleEvidence: [oracleEvidence],
            healthEvidence: [RTLVerificationEvidenceRecord(
                evidenceID: "health-1",
                kind: .healthCheck,
                artifactIDs: ["health"],
                implementationID: "impl",
                implementationVersion: "1",
                summary: "Health check passed.",
                checkedAt: date
            )],
            artifacts: [
                artifact(id: "corpus", path: "corpus/case-1.json", fill: "a"),
                artifact(id: "native", path: "oracle/native.json", fill: "e"),
                artifact(id: "oracle", path: "oracle/result.json", fill: "f"),
                artifact(id: "health", path: "health/check.json", fill: "1")
            ],
            provenance: "record-run:record-1",
            recordedAt: date,
            validUntil: Date(timeIntervalSince1970: 2_000)
        )
    }

    private func artifact(
        id: String,
        path: String,
        fill: Character
    ) -> RTLArtifactReference {
        makeTestArtifactReference(
            artifactID: id,
            path: path,
            kind: .report,
            format: .json,
            sha256: String(repeating: fill, count: 64),
            byteCount: 1
        )
    }
}
