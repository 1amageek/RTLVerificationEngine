import CircuiteFoundation
import Foundation

public struct RTLVerificationOracleEvidenceBuildResult: Sendable, Hashable, Codable {
    public var evidence: RTLVerificationOracleEvidence
    public var nativeArtifact: ArtifactReference
    public var oracleArtifact: ArtifactReference
    public var evidenceArtifact: ArtifactReference

    public init(
        evidence: RTLVerificationOracleEvidence,
        nativeArtifact: ArtifactReference,
        oracleArtifact: ArtifactReference,
        evidenceArtifact: ArtifactReference
    ) {
        self.evidence = evidence
        self.nativeArtifact = nativeArtifact
        self.oracleArtifact = oracleArtifact
        self.evidenceArtifact = evidenceArtifact
    }
}
