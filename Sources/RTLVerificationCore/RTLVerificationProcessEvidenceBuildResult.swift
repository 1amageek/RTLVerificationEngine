import Foundation

public struct RTLVerificationProcessEvidenceBuildResult: Sendable, Hashable, Codable {
    public var record: RTLVerificationProcessEvidenceRecord
    public var evidence: RTLVerificationProcessEvidenceBundle

    public init(
        record: RTLVerificationProcessEvidenceRecord,
        evidence: RTLVerificationProcessEvidenceBundle
    ) {
        self.record = record
        self.evidence = evidence
    }
}
