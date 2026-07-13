import Foundation
import XcircuitePackage

public struct RTLVerificationPayload: Sendable, Hashable, Codable {
    public var requestDigest: String?
    public var analysis: RTLVerificationAnalysis
    public var findingCount: Int
    public var proofStatus: String?
    public var findings: [RTLVerificationFinding]
    public var coverage: RTLVerificationCoverage
    public var appliedWaivers: [RTLVerificationWaiver]
    public var counterexampleArtifactIDs: [String]
    public var reportVersion: Int
    public var qualification: RTLVerificationQualificationReport
    public var proofView: RTLVerificationProofView
    public var assumptions: [RTLVerificationAssumption]

    private enum CodingKeys: String, CodingKey {
        case requestDigest
        case analysis
        case findingCount
        case proofStatus
        case findings
        case coverage
        case appliedWaivers
        case counterexampleArtifactIDs
        case reportVersion
        case qualification
        case proofView
        case assumptions
    }

    public init(
        findingCount: Int,
        requestDigest: String? = nil,
        proofStatus: String? = nil,
        analysis: RTLVerificationAnalysis = .lint,
        findings: [RTLVerificationFinding] = [],
        coverage: RTLVerificationCoverage = RTLVerificationCoverage(),
        appliedWaivers: [RTLVerificationWaiver] = [],
        counterexampleArtifactIDs: [String] = [],
        reportVersion: Int = 1,
        qualification: RTLVerificationQualificationReport = RTLVerificationQualificationReport(),
        proofView: RTLVerificationProofView = .rtlToRtlStructural,
        assumptions: [RTLVerificationAssumption] = []
    ) {
        self.requestDigest = requestDigest
        self.analysis = analysis
        self.findingCount = findingCount
        self.proofStatus = proofStatus
        self.findings = findings
        self.coverage = coverage
        self.appliedWaivers = appliedWaivers
        self.counterexampleArtifactIDs = counterexampleArtifactIDs
        self.reportVersion = reportVersion
        self.qualification = qualification
        self.proofView = proofView
        self.assumptions = assumptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            findingCount: try container.decode(Int.self, forKey: .findingCount),
            requestDigest: try container.decodeIfPresent(String.self, forKey: .requestDigest),
            proofStatus: try container.decodeIfPresent(String.self, forKey: .proofStatus),
            analysis: try container.decodeIfPresent(RTLVerificationAnalysis.self, forKey: .analysis) ?? .lint,
            findings: try container.decodeIfPresent([RTLVerificationFinding].self, forKey: .findings) ?? [],
            coverage: try container.decodeIfPresent(RTLVerificationCoverage.self, forKey: .coverage) ?? RTLVerificationCoverage(),
            appliedWaivers: try container.decodeIfPresent([RTLVerificationWaiver].self, forKey: .appliedWaivers) ?? [],
            counterexampleArtifactIDs: try container.decodeIfPresent([String].self, forKey: .counterexampleArtifactIDs) ?? [],
            reportVersion: try container.decodeIfPresent(Int.self, forKey: .reportVersion) ?? 1,
            qualification: try container.decodeIfPresent(
                RTLVerificationQualificationReport.self,
                forKey: .qualification
            ) ?? RTLVerificationQualificationReport(),
            proofView: try container.decodeIfPresent(RTLVerificationProofView.self, forKey: .proofView) ?? .rtlToRtlStructural,
            assumptions: try container.decodeIfPresent([RTLVerificationAssumption].self, forKey: .assumptions) ?? []
        )
    }
}
