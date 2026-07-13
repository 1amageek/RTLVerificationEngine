import Foundation

public struct RTLVerificationProcessQualificationEvidenceBuildResult: Sendable, Hashable, Codable {
    public var qualification: RTLVerificationProcessQualificationRecord
    public var evidence: RTLVerificationProcessQualificationEvidence

    public init(
        qualification: RTLVerificationProcessQualificationRecord,
        evidence: RTLVerificationProcessQualificationEvidence
    ) {
        self.qualification = qualification
        self.evidence = evidence
    }
}
