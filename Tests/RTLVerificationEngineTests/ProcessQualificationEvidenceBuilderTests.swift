import Foundation
import Testing
import RTLVerificationCore

@Suite("RTL process qualification evidence builder")
struct ProcessQualificationEvidenceBuilderTests {
    @Test("builder creates process-qualified evidence from retained artifacts")
    func buildsProcessQualificationEvidence() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let result = try RTLVerificationProcessQualificationEvidenceBuilder().build(
            makeRequest(),
            at: date
        )

        #expect(result.qualification.isQualified(at: date))
        #expect(result.evidence.isAuditable)
        #expect(result.evidence.matches(result.qualification, at: date))
        #expect(result.qualification.corpusEvidenceIDs == ["corpus:case-1"])
        #expect(result.qualification.oracleEvidenceIDs == ["oracle:case-1"])
        #expect(result.qualification.healthEvidenceIDs == ["health-1"])
    }

    @Test("builder rejects evidence that references a missing artifact")
    func rejectsMissingArtifact() throws {
        var request = makeRequest()
        request.artifacts.removeAll { $0.artifactID == "health" }

        do {
            _ = try RTLVerificationProcessQualificationEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("A process qualification must retain every referenced artifact.")
        } catch let error as RTLVerificationProcessQualificationEvidenceBuildError {
            #expect(error == .missingArtifact("health"))
        }
    }

    @Test("builder rejects an oracle with a different request digest")
    func rejectsOracleDigestMismatch() throws {
        var request = makeRequest()
        request.oracleEvidence[0].requestDigest = "different-request"

        do {
            _ = try RTLVerificationProcessQualificationEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("An oracle evidence artifact must bind to the qualified request.")
        } catch let error as RTLVerificationProcessQualificationEvidenceBuildError {
            #expect(error == .invalidEvidence("oracle-evidence:case-1"))
        }
    }

    @Test("builder rejects an unreferenced retained artifact")
    func rejectsUnreferencedArtifact() throws {
        var request = makeRequest()
        request.artifacts.append(artifact(id: "unreferenced", path: "extra.json", fill: "2"))

        do {
            _ = try RTLVerificationProcessQualificationEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("Every retained process qualification artifact must be referenced.")
        } catch let error as RTLVerificationProcessQualificationEvidenceBuildError {
            #expect(error == .invalidInput(
                "every retained artifact must be referenced by qualification evidence"
            ))
        }
    }

    @Test("builder rejects a validity window that is not current")
    func rejectsExpiredWindow() throws {
        var request = makeRequest()
        request.expiresAt = Date(timeIntervalSince1970: 900)

        do {
            _ = try RTLVerificationProcessQualificationEvidenceBuilder().build(
                request,
                at: Date(timeIntervalSince1970: 1_000)
            )
            Issue.record("Expired process qualification evidence must not be generated.")
        } catch let error as RTLVerificationProcessQualificationEvidenceBuildError {
            #expect(error == .invalidValidityWindow)
        }
    }

    private func makeRequest() -> RTLVerificationProcessQualificationEvidenceBuildRequest {
        let date = Date(timeIntervalSince1970: 900)
        let scope = RTLVerificationProcessQualificationScope(
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
        return RTLVerificationProcessQualificationEvidenceBuildRequest(
            qualificationID: "qualification-1",
            requestDigest: "request",
            scope: scope,
            corpusEvidence: [RTLVerificationQualificationEvidence(
                evidenceID: "corpus:case-1",
                kind: .corpus,
                artifactIDs: ["corpus"],
                scopeID: "case-1",
                summary: "Corpus case passed.",
                checkedAt: date
            )],
            oracleEvidence: [oracleEvidence],
            healthEvidence: [RTLVerificationQualificationEvidence(
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
            provenance: "qualification-run:qualification-1",
            qualifiedAt: date,
            expiresAt: Date(timeIntervalSince1970: 2_000)
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
