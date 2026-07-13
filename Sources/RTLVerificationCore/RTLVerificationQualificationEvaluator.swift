import Foundation

public struct RTLVerificationQualificationEvaluator: Sendable {
    public init() {}

    public func evaluate(
        implementationID: String,
        implementationVersion: String,
        healthEvidence: [RTLVerificationQualificationEvidence] = [],
        corpusEvaluations: [RTLVerificationCorpusEvaluation],
        oracleReports: [RTLVerificationOracleCorrelationReport],
        oracleEvidence: [RTLVerificationOracleEvidence] = [],
        processQualification: RTLVerificationProcessQualificationRecord?,
        releaseApproval: RTLVerificationQualificationEvidence? = nil,
        expectedRequestDigest: String? = nil,
        analysis: RTLVerificationAnalysis? = nil,
        proofView: RTLVerificationProofView? = nil,
        checkedAt: Date = Date()
    ) -> RTLVerificationQualificationReport {
        let orderedCorpus = corpusEvaluations.sorted { $0.caseID < $1.caseID }
        let orderedOracle = oracleReports.sorted { $0.caseID < $1.caseID }
        let corpusPassed = !orderedCorpus.isEmpty && orderedCorpus.allSatisfy(\.matched)
        let validOracleEvidence = orderedOracle.filter { report in
            oracleEvidence.contains { evidence in
                evidence.caseID == report.caseID
                    && evidence.report == report
                    && evidence.isAuditable
                    && expectedRequestDigest != nil
                    && evidence.requestDigest == expectedRequestDigest
            }
        }
        let validHealthEvidence = healthEvidence.filter {
            $0.kind == .healthCheck && $0.isAuditable
        }
        let oraclePassed = !orderedOracle.isEmpty
            && validOracleEvidence.count == orderedOracle.count
            && expectedRequestDigest != nil
            && orderedOracle.allSatisfy { $0.matched && $0.independenceVerified }
        let processBlockers = processQualification.map {
            processQualificationBlockers(
                $0,
                implementationID: implementationID,
                implementationVersion: implementationVersion,
                analysis: analysis,
                proofView: proofView,
                availableHealthEvidenceIDs: validHealthEvidence.map(\.evidenceID),
                requiredCorpusEvidenceIDs: orderedCorpus
                    .filter(\.matched)
                    .map { "corpus:\($0.caseID)" },
                requiredOracleEvidenceIDs: validOracleEvidence
                    .map { "oracle:\($0.caseID)" },
                checkedAt: checkedAt
            )
        } ?? []
        let processPassed = processQualification != nil && processBlockers.isEmpty
        let releaseApprovalPassed = releaseApproval?.kind == .releaseApproval
            && releaseApproval?.isAuditable == true

        var evidence: [RTLVerificationQualificationEvidence] = []
        for evaluation in orderedCorpus where evaluation.matched {
            evidence.append(RTLVerificationQualificationEvidence(
                evidenceID: "corpus:\(evaluation.caseID)",
                kind: .corpus,
                scopeID: evaluation.caseID,
                summary: "Retained corpus case \(evaluation.caseID) matched its expected status and finding set.",
                checkedAt: checkedAt
            ))
        }
        for report in orderedOracle {
            if let oracleEvidenceItem = oracleEvidence.first(where: {
                $0.caseID == report.caseID && $0.report == report && $0.isAuditable
                    && expectedRequestDigest != nil
                    && $0.requestDigest == expectedRequestDigest
            }),
               let qualificationEvidence = report.qualificationEvidence(
                evidenceID: "oracle:\(report.caseID)",
                artifactIDs: oracleEvidenceItem.artifactIDs,
                scopeID: report.caseID
            ) {
                evidence.append(qualificationEvidence)
            }
        }
        if let processQualification, processPassed {
            evidence.append(RTLVerificationQualificationEvidence(
                evidenceID: "process:\(processQualification.qualificationID)",
                kind: .processQualification,
                scopeID: processQualification.qualificationID,
                summary: "Process qualification \(processQualification.qualificationID) covers the declared implementation and process scope.",
                checkedAt: checkedAt
            ))
        }
        for healthItem in validHealthEvidence where processQualification?.healthEvidenceIDs.contains(healthItem.evidenceID) == true {
            evidence.append(healthItem)
        }
        if let releaseApproval, releaseApprovalPassed {
            evidence.append(releaseApproval)
        }

        var blockers: [String] = []
        if !corpusPassed {
            blockers.append("independent_corpus_validation_required")
            blockers.append(contentsOf: orderedCorpus.filter { !$0.matched }.map { "corpus_mismatch:\($0.caseID)" })
        }
        if !oraclePassed {
            blockers.append("oracle_correlation_required")
            blockers.append(contentsOf: orderedOracle.filter { !$0.matched || !$0.independenceVerified }.map { "oracle_mismatch:\($0.caseID)" })
            blockers.append(contentsOf: orderedOracle.filter { report in
                !oracleEvidence.contains { evidence in
                    evidence.caseID == report.caseID
                        && evidence.report == report
                        && evidence.isAuditable
                        && expectedRequestDigest != nil
                        && evidence.requestDigest == expectedRequestDigest
                }
            }.map { "oracle_evidence_artifact_required:\($0.caseID)" })
            if !orderedOracle.isEmpty, expectedRequestDigest == nil {
                blockers.append("oracle_request_digest_required")
            }
        }
        if !processPassed {
            blockers.append("process_qualification_required")
            blockers.append(contentsOf: processBlockers.map { "process:\($0)" })
        }

        let evidenceReadyForRelease = corpusPassed && oraclePassed && processPassed
        if evidenceReadyForRelease, !releaseApprovalPassed {
            blockers.append("release_approval_required")
        }

        let state: RTLVerificationQualificationState
        if !corpusPassed {
            state = .unassessed
        } else if !oraclePassed {
            state = .corpusChecked
        } else if !processPassed {
            state = .oracleCorrelated
        } else if releaseApprovalPassed {
            state = .releaseEligible
        } else {
            state = .processQualified
        }

        let limitations = orderedCorpus.flatMap { evaluation in
            evaluation.mismatches.map { "Corpus \(evaluation.caseID): \($0.message)" }
        } + orderedOracle.flatMap { report in
            report.mismatches.map { "Oracle \(report.caseID): \($0.message)" }
        }
        return RTLVerificationQualificationReport(
            implementationID: implementationID,
            implementationVersion: implementationVersion,
            state: state,
            evidence: evidence.sorted { $0.evidenceID < $1.evidenceID },
            blockers: Array(Set(blockers)).sorted(),
            limitations: limitations,
            processQualification: processQualification,
            checkedAt: checkedAt
        )
    }

    private func processQualificationBlockers(
        _ record: RTLVerificationProcessQualificationRecord,
        implementationID: String,
        implementationVersion: String,
        analysis: RTLVerificationAnalysis?,
        proofView: RTLVerificationProofView?,
        availableHealthEvidenceIDs: [String],
        requiredCorpusEvidenceIDs: [String],
        requiredOracleEvidenceIDs: [String],
        checkedAt: Date
    ) -> [String] {
        var blockers = record.blockers
        guard record.isQualified(at: checkedAt) else {
            blockers.append("record_not_current")
            return Array(Set(blockers)).sorted()
        }
        if record.scope.implementationID != implementationID {
            blockers.append("scope_implementation_mismatch")
        }
        if record.scope.algorithmVersion != implementationVersion {
            blockers.append("scope_algorithm_version_mismatch")
        }
        if let analysis, !record.scope.analyses.contains(analysis) {
            blockers.append("scope_analysis_mismatch")
        }
        if analysis == .formalEquivalence,
           let proofView,
           !record.scope.proofViews.contains(proofView) {
            blockers.append("scope_proof_view_mismatch")
        }
        let corpusEvidence = Set(record.corpusEvidenceIDs)
        let healthEvidence = Set(record.healthEvidenceIDs)
        let availableHealthEvidence = Set(availableHealthEvidenceIDs)
        blockers.append(contentsOf: record.healthEvidenceIDs
            .filter { !availableHealthEvidence.contains($0) }
            .map { "health_evidence_artifact_missing:\($0)" })
        blockers.append(contentsOf: availableHealthEvidenceIDs
            .filter { !healthEvidence.contains($0) }
            .map { "health_evidence_binding_missing:\($0)" })
        blockers.append(contentsOf: requiredCorpusEvidenceIDs
            .filter { !corpusEvidence.contains($0) }
            .map { "corpus_evidence_binding_missing:\($0)" })
        let oracleEvidence = Set(record.oracleEvidenceIDs)
        blockers.append(contentsOf: requiredOracleEvidenceIDs
            .filter { !oracleEvidence.contains($0) }
            .map { "oracle_evidence_binding_missing:\($0)" })
        return Array(Set(blockers)).sorted()
    }
}
