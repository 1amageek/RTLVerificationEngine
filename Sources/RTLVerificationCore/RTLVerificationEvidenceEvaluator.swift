import Foundation

public struct RTLVerificationEvidenceEvaluator: Sendable {
    public init() {}

    public func evaluate(
        implementationID: String,
        implementationVersion: String,
        corpusEvaluations: [RTLVerificationCorpusEvaluation],
        oracleReports: [RTLVerificationOracleCorrelationReport],
        oracleEvidence: [RTLVerificationOracleEvidence] = [],
        expectedRequestDigest: String? = nil,
        checkedAt: Date = Date()
    ) -> RTLVerificationEvidenceAssessment {
        let orderedCorpus = corpusEvaluations.sorted { $0.caseID < $1.caseID }
        let orderedOracle = oracleReports.sorted { $0.caseID < $1.caseID }
        let corpusObserved = !orderedCorpus.isEmpty && orderedCorpus.allSatisfy(\.matched)
        let correlatedOracleEvidence = orderedOracle.compactMap { report in
            oracleEvidence.first { evidence in
                evidence.caseID == report.caseID
                    && evidence.report == report
                    && evidence.isAuditable
                    && expectedRequestDigest != nil
                    && evidence.requestDigest == expectedRequestDigest
            }
        }
        let oracleCorrelated = corpusObserved
            && !orderedOracle.isEmpty
            && orderedOracle.allSatisfy { $0.matched && $0.independenceVerified }
            && correlatedOracleEvidence.count == orderedOracle.count

        var evidence: [RTLVerificationEvidenceRecord] = orderedCorpus
            .filter(\.matched)
            .map { evaluation in
                RTLVerificationEvidenceRecord(
                    evidenceID: "corpus:\(evaluation.caseID)",
                    kind: .corpus,
                    scopeID: evaluation.caseID,
                    summary: "Retained corpus case \(evaluation.caseID) matched its expected observations.",
                    checkedAt: checkedAt
                )
            }
        for report in orderedOracle {
            guard let oracleEvidenceItem = correlatedOracleEvidence.first(where: { $0.caseID == report.caseID }),
                  let observation = report.evidenceRecord(
                    evidenceID: "oracle:\(report.caseID)",
                    artifactIDs: oracleEvidenceItem.artifactIDs,
                    scopeID: report.caseID
                  ) else {
                continue
            }
            evidence.append(observation)
        }

        let maturity: RTLVerificationEvidenceMaturity
        if oracleCorrelated {
            maturity = .oracleCorrelated
        } else if corpusObserved {
            maturity = .corpusObserved
        } else {
            maturity = .unassessed
        }
        let limitations = orderedCorpus.flatMap { evaluation in
            evaluation.mismatches.map { "Corpus \(evaluation.caseID): \($0.message)" }
        } + orderedOracle.flatMap { report in
            report.mismatches.map { "Oracle \(report.caseID): \($0.message)" }
        }
        return RTLVerificationEvidenceAssessment(
            implementationID: implementationID,
            implementationVersion: implementationVersion,
            maturity: maturity,
            evidence: evidence.sorted { $0.evidenceID < $1.evidenceID },
            limitations: limitations,
            checkedAt: checkedAt
        )
    }
}
