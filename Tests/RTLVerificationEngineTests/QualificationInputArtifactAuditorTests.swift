import Foundation
import Testing
import RTLVerificationCore

@Suite("RTL qualification input artifact auditor")
struct QualificationInputArtifactAuditorTests {
    @Test("auditor verifies retained process artifacts")
    func verifiesRetainedProcessArtifacts() throws {
        let root = try makeTemporaryRoot()
        let reference = try makeArtifact(
            root: root,
            path: "qualification/process.json",
            artifactID: "process-artifact",
            contents: Data("process-evidence".utf8)
        )
        let input = RTLVerificationQualificationInput(
            processEvidence: [makeProcessEvidence(artifact: reference)]
        )

        try RTLVerificationQualificationInputArtifactAuditor().audit(
            input,
            reader: FileSystemRTLArtifactReader(projectRoot: root)
        )
    }

    @Test("auditor rejects a process artifact modified after retention")
    func rejectsModifiedProcessArtifact() throws {
        let root = try makeTemporaryRoot()
        let path = root.appending(path: "qualification/process.json")
        let original = Data("process-evidence".utf8)
        let reference = try makeArtifact(
            root: root,
            path: "qualification/process.json",
            artifactID: "process-artifact",
            contents: original
        )
        try Data("modified-evidence".utf8).write(to: path)
        let input = RTLVerificationQualificationInput(
            processEvidence: [makeProcessEvidence(artifact: reference)]
        )

        do {
            try RTLVerificationQualificationInputArtifactAuditor().audit(
                input,
                reader: FileSystemRTLArtifactReader(projectRoot: root)
            )
            Issue.record("A modified retained artifact must fail integrity verification.")
        } catch let error as RTLVerificationQualificationInputArtifactAuditError {
            guard case .artifactReadFailed(let artifactID, let artifactPath, _) = error else {
                Issue.record("The auditor returned an unexpected error: \(error.localizedDescription)")
                return
            }
            #expect(artifactID == "process-artifact")
            #expect(artifactPath == "qualification/process.json")
        }
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "rtl-qualification-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeArtifact(
        root: URL,
        path: String,
        artifactID: String,
        contents: Data
    ) throws -> RTLArtifactReference {
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

    private func makeProcessEvidence(
        artifact: RTLArtifactReference
    ) -> RTLVerificationProcessQualificationEvidence {
        let recordedAt = Date(timeIntervalSince1970: 1_000)
        let qualification = RTLVerificationProcessQualificationRecord(
            qualificationID: "qualification-1",
            scope: RTLVerificationProcessQualificationScope(
                implementationID: "rtl-tool",
                binaryDigest: String(repeating: "a", count: 64),
                algorithmVersion: "1",
                processProfileID: "profile-1",
                pdkID: "pdk-1",
                pdkDigest: String(repeating: "b", count: 64),
                deckDigest: String(repeating: "c", count: 64),
                analyses: [.lint]
            ),
            status: .qualified,
            corpusEvidenceIDs: ["corpus-1"],
            oracleEvidenceIDs: ["oracle-1"],
            healthEvidenceIDs: ["health-1"],
            qualifiedAt: recordedAt.addingTimeInterval(-10),
            expiresAt: recordedAt.addingTimeInterval(10)
        )
        return RTLVerificationProcessQualificationEvidence(
            evidenceID: "process-evidence-1",
            qualificationID: qualification.qualificationID,
            qualification: qualification,
            artifactIDs: [artifact.artifactID].compactMap { $0 },
            artifacts: [artifact],
            provenance: "fixture",
            recordedAt: recordedAt
        )
    }
}
