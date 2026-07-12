import Foundation

public struct RTLVerificationQualificationEvaluator: Sendable {
    public init() {}

    public func evaluate(
        implementationID: String,
        implementationVersion: String,
        corpusEvaluations: [RTLVerificationCorpusEvaluation],
        oracleReports: [RTLVerificationOracleCorrelationReport],
        oracleEvidence: [RTLVerificationOracleEvidence] = [],
        processQualification: RTLVerificationProcessQualificationRecord?,
        releaseApproval: RTLVerificationQualificationEvidence? = nil,
        expectedRequestDigest: String? = nil,
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
        let oraclePassed = !orderedOracle.isEmpty
            && validOracleEvidence.count == orderedOracle.count
            && expectedRequestDigest != nil
            && orderedOracle.allSatisfy { $0.matched && $0.independenceVerified }
        let processPassed = processQualification?.isQualified(at: checkedAt) == true

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
        if let processQualification, processQualification.isQualified(at: checkedAt) {
            evidence.append(RTLVerificationQualificationEvidence(
                evidenceID: "process:\(processQualification.qualificationID)",
                kind: .processQualification,
                scopeID: processQualification.qualificationID,
                summary: "Process qualification \(processQualification.qualificationID) covers the declared implementation and process scope.",
                checkedAt: checkedAt
            ))
        }
        if let releaseApproval, releaseApproval.kind == .releaseApproval {
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
            if let processQualification {
                blockers.append(contentsOf: processQualification.blockers.map { "process:\($0)" })
            }
        }

        let evidenceReadyForRelease = corpusPassed && oraclePassed && processPassed
        if evidenceReadyForRelease,
           releaseApproval?.kind != .releaseApproval {
            blockers.append("release_approval_required")
        }

        let state: RTLVerificationQualificationState
        if !corpusPassed {
            state = .unassessed
        } else if !oraclePassed {
            state = .corpusChecked
        } else if !processPassed {
            state = .oracleCorrelated
        } else if releaseApproval?.kind == .releaseApproval {
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
}
