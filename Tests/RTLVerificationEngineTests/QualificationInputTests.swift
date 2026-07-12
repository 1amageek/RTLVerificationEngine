import Foundation
import LogicIR
import Testing
import RTLVerificationCore
import RTLLint
import XcircuitePackage

@Suite("RTL verification qualification input")
struct QualificationInputTests {
    @Test("qualification input is applied to the native result", .timeLimit(.minutes(1)))
    func qualificationInputIsApplied() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let rtl = XcircuiteFileReference(
            artifactID: "rtl-input",
            path: "top.sv",
            kind: .rtl,
            format: .systemVerilog,
            sha256: XcircuiteHasher().sha256(data: Data(source.utf8)),
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
        let oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle:\(caseID)",
            caseID: caseID,
            requestDigest: "request-digest",
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
        let processScope = RTLVerificationProcessQualificationScope(
            implementationID: "native-rtl-verification",
            binaryDigest: "binary-digest",
            algorithmVersion: "1.0.0",
            processProfileID: "process-profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.lint]
        )
        let processQualification = RTLVerificationProcessQualificationRecord(
            qualificationID: "process-qualification",
            scope: processScope,
            status: .qualified,
            corpusEvidenceIDs: ["corpus:\(caseID)"],
            oracleEvidenceIDs: ["oracle:\(caseID)"],
            healthEvidenceIDs: ["health:lint"],
            qualifiedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60)
        )
        let qualificationInput = RTLVerificationQualificationInput(
            corpusEvaluations: [RTLVerificationCorpusEvaluation(
                caseID: caseID,
                matched: true,
                observedStatus: .completed,
                observedFindingCodes: [],
                mismatches: []
            )],
            oracleReports: [oracleReport],
            oracleEvidence: [oracleEvidence],
            processQualification: processQualification,
            releaseApproval: RTLVerificationQualificationEvidence(
                evidenceID: "approval-1",
                kind: .releaseApproval,
                summary: "Approved by verification owner.",
                checkedAt: now
            ),
            expectedRequestDigest: "request-digest"
        )
        let request = RTLVerificationRequest(
            runID: "qualification-input",
            inputs: [rtl],
            design: LogicDesignReference(
                artifact: rtl,
                topDesignName: "top",
                designDigest: rtl.sha256 ?? ""
            ),
            analysis: .lint,
            policy: RTLVerificationPolicy(minimumQualification: .releaseEligible),
            qualificationInput: qualificationInput
        )

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.qualification.state == .releaseEligible)
        #expect(envelope.payload.qualification.isReleaseEligible)
        #expect(envelope.payload.qualification.blockers.isEmpty)
    }

    private func jsonReference(artifactID: String, path: String, data: Data) -> XcircuiteFileReference {
        XcircuiteFileReference(
            artifactID: artifactID,
            path: path,
            kind: .report,
            format: .json,
            sha256: XcircuiteHasher().sha256(data: data),
            byteCount: Int64(data.count)
        )
    }
}
