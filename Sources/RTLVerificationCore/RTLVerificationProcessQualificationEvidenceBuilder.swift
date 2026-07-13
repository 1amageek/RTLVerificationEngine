import Foundation

public struct RTLVerificationProcessQualificationEvidenceBuilder: RTLVerificationProcessQualificationEvidenceBuilding {
    public init() {}

    public func build(
        _ request: RTLVerificationProcessQualificationEvidenceBuildRequest,
        at date: Date
    ) throws -> RTLVerificationProcessQualificationEvidenceBuildResult {
        guard request.schemaVersion == RTLVerificationProcessQualificationEvidenceBuildRequest.currentSchemaVersion else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
                "unsupported schema version \(request.schemaVersion)"
            )
        }
        guard !request.qualificationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.requestDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
                "qualificationID, requestDigest and provenance are required"
            )
        }
        guard request.scope.isComplete else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
                "complete PDK and analysis scope is required"
            )
        }
        guard request.qualifiedAt < request.expiresAt else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidValidityWindow
        }
        guard request.qualifiedAt <= date, date < request.expiresAt else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.notValidAt
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
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
                "every retained artifact must be referenced by qualification evidence"
            )
        }

        let qualification = RTLVerificationProcessQualificationRecord(
            qualificationID: request.qualificationID,
            scope: request.scope,
            status: .qualified,
            corpusEvidenceIDs: corpusIDs,
            oracleEvidenceIDs: oracleIDs,
            healthEvidenceIDs: healthIDs,
            blockers: [],
            qualifiedAt: request.qualifiedAt,
            expiresAt: request.expiresAt
        )
        let evidence = RTLVerificationProcessQualificationEvidence(
            evidenceID: "process-evidence:\(request.qualificationID)",
            qualificationID: request.qualificationID,
            qualification: qualification,
            artifactIDs: artifactIDs.sorted(),
            artifacts: request.artifacts,
            provenance: request.provenance,
            recordedAt: date
        )
        guard evidence.isAuditable else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
                "the generated process evidence did not satisfy its audit contract"
            )
        }
        return RTLVerificationProcessQualificationEvidenceBuildResult(
            qualification: qualification,
            evidence: evidence
        )
    }

    private func validateCorpus(
        _ evidence: [RTLVerificationQualificationEvidence],
        artifactIDs: Set<String>
    ) throws -> [String] {
        guard !evidence.isEmpty else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.missingEvidence(kind: .corpus)
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
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
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
            throw RTLVerificationProcessQualificationEvidenceBuildError.missingEvidence(
                kind: .oracleCorrelation
            )
        }
        var caseIDs = Set<String>()
        for item in evidence {
            guard item.requestDigest == requestDigest,
                  item.isAuditable else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidEvidence(item.evidenceID)
            }
            guard caseIDs.insert(item.caseID).inserted else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidEvidence(item.caseID)
            }
            try validateReferencedArtifacts(item.artifactIDs, available: artifactIDs)
        }
        return evidence.map { "oracle:\($0.caseID)" }.sorted()
    }

    private func validateHealth(
        _ evidence: [RTLVerificationQualificationEvidence],
        scope: RTLVerificationProcessQualificationScope,
        artifactIDs: Set<String>
    ) throws -> [String] {
        guard !evidence.isEmpty else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.missingEvidence(kind: .healthCheck)
        }
        var evidenceIDs = Set<String>()
        let ids = try evidence.map { item in
            guard item.kind == .healthCheck,
                  item.isAuditable,
                  item.implementationID == scope.implementationID,
                  item.implementationVersion == scope.algorithmVersion,
                  evidenceIDs.insert(item.evidenceID).inserted else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidEvidence(item.evidenceID)
            }
            guard !item.artifactIDs.isEmpty else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidEvidence(item.evidenceID)
            }
            try validateReferencedArtifacts(item.artifactIDs, available: artifactIDs)
            return item.evidenceID
        }
        return ids.sorted()
    }

    private func validateEvidenceGroup(
        _ evidence: [RTLVerificationQualificationEvidence],
        expectedKind: RTLVerificationQualificationEvidenceKind,
        artifactIDs: Set<String>
    ) throws -> [String] {
        var evidenceIDs = Set<String>()
        for item in evidence {
            guard item.kind == expectedKind,
                  item.isAuditable,
                  !item.artifactIDs.isEmpty,
                  evidenceIDs.insert(item.evidenceID).inserted else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidEvidence(
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
                throw RTLVerificationProcessQualificationEvidenceBuildError.missingArtifact(reference)
            }
        }
    }

    private func validateArtifacts(
        _ artifacts: [RTLArtifactReference]
    ) throws -> Set<String> {
        guard !artifacts.isEmpty else {
            throw RTLVerificationProcessQualificationEvidenceBuildError.invalidInput(
                "at least one retained artifact is required"
            )
        }
        var artifactIDs = Set<String>()
        for artifact in artifacts {
            guard let artifactID = artifact.artifactID,
                  !artifactID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidArtifact(artifact.path)
            }
            guard artifactIDs.insert(artifactID).inserted,
                  !artifact.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !artifact.path.hasPrefix("/"),
                  !artifact.path.split(separator: "/").contains(".."),
                  let sha256 = artifact.sha256,
                  sha256.count == 64,
                  sha256.allSatisfy(\.isHexDigit),
                  artifact.byteCount >= 0 else {
                throw RTLVerificationProcessQualificationEvidenceBuildError.invalidArtifact(artifactID)
            }
        }
        return artifactIDs
    }
}
