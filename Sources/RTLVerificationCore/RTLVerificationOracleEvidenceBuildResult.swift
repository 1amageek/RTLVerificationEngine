import Foundation

public struct RTLVerificationOracleEvidenceBuildResult: Sendable, Hashable, Codable {
    public var evidence: RTLVerificationOracleEvidence
    public var nativeArtifact: RTLArtifactReference
    public var oracleArtifact: RTLArtifactReference
    public var evidenceArtifact: RTLArtifactReference

    public init(
        evidence: RTLVerificationOracleEvidence,
        nativeArtifact: RTLArtifactReference,
        oracleArtifact: RTLArtifactReference,
        evidenceArtifact: RTLArtifactReference
    ) {
        self.evidence = evidence
        self.nativeArtifact = nativeArtifact
        self.oracleArtifact = oracleArtifact
        self.evidenceArtifact = evidenceArtifact
    }
}
