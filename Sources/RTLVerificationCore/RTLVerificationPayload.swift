import Foundation

public struct RTLVerificationPayload: Sendable, Hashable, Codable {
    public var requestDigest: String?
    public var analysis: RTLVerificationAnalysis
    public var findingCount: Int
    public var proofStatus: String?
    public var findings: [RTLVerificationFinding]
    public var coverage: RTLVerificationCoverage
    public var appliedWaivers: [RTLVerificationWaiver]
    public var counterexampleArtifactIDs: [String]
    public var proofArtifactIDs: [String]
    public var reportVersion: Int
    public var record: RTLVerificationEvidenceAssessment
    public var proofView: RTLVerificationProofView
    public var assumptions: [RTLVerificationAssumption]

    public init(
        findingCount: Int,
        requestDigest: String? = nil,
        proofStatus: String? = nil,
        analysis: RTLVerificationAnalysis = .lint,
        findings: [RTLVerificationFinding] = [],
        coverage: RTLVerificationCoverage = RTLVerificationCoverage(),
        appliedWaivers: [RTLVerificationWaiver] = [],
        counterexampleArtifactIDs: [String] = [],
        proofArtifactIDs: [String] = [],
        reportVersion: Int = 1,
        record: RTLVerificationEvidenceAssessment = RTLVerificationEvidenceAssessment(),
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
        self.proofArtifactIDs = proofArtifactIDs
        self.reportVersion = reportVersion
        self.record = record
        self.proofView = proofView
        self.assumptions = assumptions
    }

}
