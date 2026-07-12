import Foundation

public struct RTLVerificationAnalysisResult: Sendable, Hashable, Codable {
    public var findings: [RTLVerificationFinding]
    public var coverage: RTLVerificationCoverage
    public var proofStatus: String?
    public var counterexampleData: Data?
    public var counterexampleArtifactID: String?
    public var qualification: RTLVerificationQualificationReport

    public init(
        findings: [RTLVerificationFinding] = [],
        coverage: RTLVerificationCoverage,
        proofStatus: String? = nil,
        counterexampleData: Data? = nil,
        counterexampleArtifactID: String? = nil,
        qualification: RTLVerificationQualificationReport = RTLVerificationQualificationReport()
    ) {
        self.findings = findings
        self.coverage = coverage
        self.proofStatus = proofStatus
        self.counterexampleData = counterexampleData
        self.counterexampleArtifactID = counterexampleArtifactID
        self.qualification = qualification
    }
}
