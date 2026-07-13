import Foundation
import XcircuitePackage

public struct RTLVerificationOracleEvidenceBuildResult: Sendable, Hashable, Codable {
    public var evidence: RTLVerificationOracleEvidence
    public var nativeArtifact: XcircuiteFileReference
    public var oracleArtifact: XcircuiteFileReference
    public var evidenceArtifact: XcircuiteFileReference

    public init(
        evidence: RTLVerificationOracleEvidence,
        nativeArtifact: XcircuiteFileReference,
        oracleArtifact: XcircuiteFileReference,
        evidenceArtifact: XcircuiteFileReference
    ) {
        self.evidence = evidence
        self.nativeArtifact = nativeArtifact
        self.oracleArtifact = oracleArtifact
        self.evidenceArtifact = evidenceArtifact
    }
}
