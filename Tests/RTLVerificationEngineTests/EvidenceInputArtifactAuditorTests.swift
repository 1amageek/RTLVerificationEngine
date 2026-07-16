import CircuiteFoundation
import Foundation
import Testing
import RTLVerificationCore

@Suite("RTL observation input artifact auditor")
struct EvidenceInputArtifactAuditorTests {
    @Test("auditor verifies retained oracle observation artifacts")
    func verifiesRetainedOracleArtifacts() throws {
        let root = try makeTemporaryRoot()
        let native = try makeArtifact(
            root: root,
            path: "observations/native.json",
            artifactID: "native-observation",
            contents: Data("native-observation".utf8)
        )
        let oracle = try makeArtifact(
            root: root,
            path: "observations/oracle.json",
            artifactID: "oracle-observation",
            contents: Data("oracle-observation".utf8)
        )
        let input = RTLVerificationEvidenceInput(
            oracleEvidence: [makeOracleEvidence(native: native, oracle: oracle)]
        )

        try RTLVerificationEvidenceInputArtifactAuditor().audit(
            input,
            reader: FileSystemRTLArtifactReader(projectRoot: root)
        )
    }

    @Test("auditor rejects an oracle observation artifact modified after retention")
    func rejectsModifiedOracleArtifact() throws {
        let root = try makeTemporaryRoot()
        let native = try makeArtifact(
            root: root,
            path: "observations/native.json",
            artifactID: "native-observation",
            contents: Data("native-observation".utf8)
        )
        let oracle = try makeArtifact(
            root: root,
            path: "observations/oracle.json",
            artifactID: "oracle-observation",
            contents: Data("oracle-observation".utf8)
        )
        try Data("modified-observation".utf8).write(to: root.appending(path: oracle.path))
        let input = RTLVerificationEvidenceInput(
            oracleEvidence: [makeOracleEvidence(native: native, oracle: oracle)]
        )

        do {
            try RTLVerificationEvidenceInputArtifactAuditor().audit(
                input,
                reader: FileSystemRTLArtifactReader(projectRoot: root)
            )
            Issue.record("A modified retained artifact must fail integrity verification.")
        } catch let error as RTLVerificationEvidenceInputArtifactAuditError {
            guard case .artifactReadFailed(let artifactID, let artifactPath, _) = error else {
                Issue.record("The auditor returned an unexpected error: \(error.localizedDescription)")
                return
            }
            #expect(artifactID == "oracle-observation")
            #expect(artifactPath == "observations/oracle.json")
        }
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "rtl-record-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeArtifact(
        root: URL,
        path: String,
        artifactID: String,
        contents: Data
    ) throws -> ArtifactReference {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url)
        let hasher = SHA256ContentDigester()
        return makeTestArtifactReference(
            artifactID: artifactID,
            path: path,
            kind: .report,
            format: .json,
            sha256: hasher.sha256(data: contents),
            byteCount: Int64(contents.count)
        )
    }

    private func makeOracleEvidence(
        native: ArtifactReference,
        oracle: ArtifactReference
    ) -> RTLVerificationOracleEvidence {
        let recordedAt = Date(timeIntervalSince1970: 1_000)
        let requestDigest = String(repeating: "d", count: 64)
        let report = RTLVerificationOracleCorrelationReport(
            caseID: "lint-observation",
            nativeImplementationID: "native-rtl-verification",
            oracleImplementationID: "independent-oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: true,
            checkedAt: recordedAt
        )
        return RTLVerificationOracleEvidence(
            evidenceID: "oracle-observation-1",
            caseID: report.caseID,
            requestDigest: requestDigest,
            nativePayloadRequestDigest: requestDigest,
            oraclePayloadRequestDigest: requestDigest,
            nativeArtifact: native,
            oracleArtifact: oracle,
            report: report,
            oracleProvenance: "independent-retained-oracle",
            recordedAt: recordedAt
        )
    }
}
