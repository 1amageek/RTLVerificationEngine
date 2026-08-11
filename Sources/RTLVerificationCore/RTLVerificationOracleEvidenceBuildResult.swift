import CircuiteFoundation
import Foundation

public struct RTLVerificationOracleEvidenceBuildResult: Sendable, Hashable, Codable {
    public var evidence: RTLVerificationOracleEvidence
    public var nativeArtifact: RTLArtifactBinding
    public var oracleArtifact: RTLArtifactBinding
    public var evidenceArtifact: RTLArtifactBinding

    public init(
        evidence: RTLVerificationOracleEvidence,
        nativeArtifact: RTLArtifactBinding,
        oracleArtifact: RTLArtifactBinding,
        evidenceArtifact: RTLArtifactBinding
    ) {
        self.evidence = evidence
        self.nativeArtifact = nativeArtifact
        self.oracleArtifact = oracleArtifact
        self.evidenceArtifact = evidenceArtifact
    }
}
