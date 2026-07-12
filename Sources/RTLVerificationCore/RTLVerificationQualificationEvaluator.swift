import Foundation

public struct RTLVerificationQualificationEvaluator: Sendable {
    public init() {}

    public func evaluate(
        implementationID: String,
        implementationVersion: String,
        corpusEvaluations: [RTLVerificationCorpusEvaluation],
        oracleReports: [RTLVerificationOracleCorrelationReport],
        processQualification: RTLVerificationProcessQualificationRecord?,
        releaseApproval: RTLVerificationQualificationEvidence? = nil,
        checkedAt: Date = Date()
    ) -> RTLVerificationQualificationReport {
        let orderedCorpus = corpusEvaluations.sorted { $0.caseID < $1.caseID }
        let orderedOracle = oracleReports.sorted { $0.caseID < $1.caseID }
        let corpusPassed = !orderedCorpus.isEmpty && orderedCorpus.allSatisfy(\.matched)
        let oraclePassed = !orderedOracle.isEmpty
            && orderedOracle.allSatisfy { $0.matched && $0.independenceVerified }
        let processPassed = processQualification?.isQualified == true

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
            if let oracleEvidence = report.qualificationEvidence(
                evidenceID: "oracle:\(report.caseID)",
                scopeID: report.caseID
            ) {
                evidence.append(oracleEvidence)
            }
        }
        if let processQualification, processQualification.isQualified {
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
            processQualification: processQualification
        )
    }
}
