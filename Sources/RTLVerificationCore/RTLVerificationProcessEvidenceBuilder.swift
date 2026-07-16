import CircuiteFoundation
import Foundation

public struct RTLVerificationProcessEvidenceBuilder: RTLVerificationProcessEvidenceBuilding {
    public init() {}

    public func build(
        _ request: RTLVerificationProcessEvidenceBuildRequest,
        at date: Date
    ) throws -> RTLVerificationProcessEvidenceBuildResult {
        guard request.schemaVersion == RTLVerificationProcessEvidenceBuildRequest.currentSchemaVersion else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "unsupported schema version \(request.schemaVersion)"
            )
        }
        guard !request.evidenceSetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.requestDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "evidenceSetID, requestDigest and provenance are required"
            )
        }
        guard request.scope.isComplete else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "complete PDK and analysis scope is required"
            )
        }
        guard request.recordedAt < request.validUntil else {
            throw RTLVerificationProcessEvidenceBuildError.invalidValidityWindow
        }
        guard request.recordedAt <= date, date < request.validUntil else {
            throw RTLVerificationProcessEvidenceBuildError.notValidAt
        }

        let artifactIDs = try validateArtifacts(request.artifacts)
        let corpusIDs = try validateCorpus(
            request.corpusEvidence,
            artifactIDs: artifactIDs
        )
        let oracleIDs = try validateOracle(
            request.oracleEvidence,
            requestDigest: request.requestDigest,
            artifactIDs: artifactIDs
        )
        let healthIDs = try validateHealth(
            request.healthEvidence,
            scope: request.scope,
            artifactIDs: artifactIDs
        )
        let referencedArtifactIDs = Set(
            request.corpusEvidence.flatMap(\.artifactIDs)
                + request.oracleEvidence.flatMap(\.artifactIDs)
                + request.healthEvidence.flatMap(\.artifactIDs)
        )
        guard referencedArtifactIDs == artifactIDs else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "every retained artifact must be referenced by record evidence"
            )
        }

        let record = RTLVerificationProcessEvidenceRecord(
            evidenceSetID: request.evidenceSetID,
            scope: request.scope,
            status: .complete,
            corpusEvidenceIDs: corpusIDs,
            oracleEvidenceIDs: oracleIDs,
            healthEvidenceIDs: healthIDs,
            blockers: [],
            recordedAt: request.recordedAt,
            validUntil: request.validUntil
        )
        let evidence = RTLVerificationProcessEvidenceBundle(
            evidenceID: "process-evidence:\(request.evidenceSetID)",
            evidenceSetID: request.evidenceSetID,
            record: record,
            artifactIDs: artifactIDs.sorted(),
            artifacts: request.artifacts,
            provenance: request.provenance,
            recordedAt: date
        )
        guard evidence.isAuditable else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "the generated process evidence did not satisfy its audit contract"
            )
        }
        return RTLVerificationProcessEvidenceBuildResult(
            record: record,
            evidence: evidence
        )
    }

    private func validateCorpus(
        _ evidence: [RTLVerificationEvidenceRecord],
        artifactIDs: Set<String>
    ) throws -> [String] {
        guard !evidence.isEmpty else {
            throw RTLVerificationProcessEvidenceBuildError.missingEvidence(kind: .corpus)
        }
        let ids = try validateEvidenceGroup(
            evidence,
            expectedKind: .corpus,
            artifactIDs: artifactIDs
        )
        guard evidence.allSatisfy({
            guard let scopeID = $0.scopeID else { return false }
            return $0.evidenceID == "corpus:\(scopeID)"
        }) else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "corpus evidence IDs must be bound to corpus case IDs"
            )
        }
        return ids
    }

    private func validateOracle(
        _ evidence: [RTLVerificationOracleEvidence],
        requestDigest: String,
        artifactIDs: Set<String>
    ) throws -> [String] {
        guard !evidence.isEmpty else {
            throw RTLVerificationProcessEvidenceBuildError.missingEvidence(
                kind: .oracleCorrelation
            )
        }
        var caseIDs = Set<String>()
        for item in evidence {
            guard item.requestDigest == requestDigest,
                  item.isAuditable else {
                throw RTLVerificationProcessEvidenceBuildError.invalidEvidence(item.evidenceID)
            }
            guard caseIDs.insert(item.caseID).inserted else {
                throw RTLVerificationProcessEvidenceBuildError.invalidEvidence(item.caseID)
            }
            try validateReferencedArtifacts(item.artifactIDs, available: artifactIDs)
        }
        return evidence.map { "oracle:\($0.caseID)" }.sorted()
    }

    private func validateHealth(
        _ evidence: [RTLVerificationEvidenceRecord],
        scope: RTLVerificationProcessEvidenceScope,
        artifactIDs: Set<String>
    ) throws -> [String] {
        guard !evidence.isEmpty else {
            throw RTLVerificationProcessEvidenceBuildError.missingEvidence(kind: .healthCheck)
        }
        var evidenceIDs = Set<String>()
        let ids = try evidence.map { item in
            guard item.kind == .healthCheck,
                  item.isAuditable,
                  item.implementationID == scope.implementationID,
                  item.implementationVersion == scope.algorithmVersion,
                  evidenceIDs.insert(item.evidenceID).inserted else {
                throw RTLVerificationProcessEvidenceBuildError.invalidEvidence(item.evidenceID)
            }
            guard !item.artifactIDs.isEmpty else {
                throw RTLVerificationProcessEvidenceBuildError.invalidEvidence(item.evidenceID)
            }
            try validateReferencedArtifacts(item.artifactIDs, available: artifactIDs)
            return item.evidenceID
        }
        return ids.sorted()
    }

    private func validateEvidenceGroup(
        _ evidence: [RTLVerificationEvidenceRecord],
        expectedKind: RTLVerificationEvidenceRecordKind,
        artifactIDs: Set<String>
    ) throws -> [String] {
        var evidenceIDs = Set<String>()
        for item in evidence {
            guard item.kind == expectedKind,
                  item.isAuditable,
                  !item.artifactIDs.isEmpty,
                  evidenceIDs.insert(item.evidenceID).inserted else {
                throw RTLVerificationProcessEvidenceBuildError.invalidEvidence(
                    item.evidenceID
                )
            }
            try validateReferencedArtifacts(item.artifactIDs, available: artifactIDs)
        }
        return evidenceIDs.sorted()
    }

    private func validateReferencedArtifacts(
        _ references: [String],
        available: Set<String>
    ) throws {
        for reference in references {
            guard available.contains(reference) else {
                throw RTLVerificationProcessEvidenceBuildError.missingArtifact(reference)
            }
        }
    }

    private func validateArtifacts(
        _ artifacts: [ArtifactReference]
    ) throws -> Set<String> {
        guard !artifacts.isEmpty else {
            throw RTLVerificationProcessEvidenceBuildError.invalidInput(
                "at least one retained artifact is required"
            )
        }
        var artifactIDs = Set<String>()
        for artifact in artifacts {
            let artifactID = artifact.artifactID
            let sha256 = artifact.sha256
            guard !artifactID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RTLVerificationProcessEvidenceBuildError.invalidArtifact(artifact.path)
            }
            guard artifactIDs.insert(artifactID).inserted,
                  !artifact.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !artifact.path.hasPrefix("/"),
                  !artifact.path.split(separator: "/").contains(".."),
                  artifact.digest.algorithm == .sha256,
                  sha256.count == 64,
                  sha256.allSatisfy(\.isHexDigit),
                  artifact.byteCount >= 0 else {
                throw RTLVerificationProcessEvidenceBuildError.invalidArtifact(artifactID)
            }
        }
        return artifactIDs
    }
}
