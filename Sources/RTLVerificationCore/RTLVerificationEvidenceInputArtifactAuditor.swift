import CircuiteFoundation
import Foundation

public struct RTLVerificationEvidenceInputArtifactAuditor: Sendable {
    public init() {}

    public func audit(
        _ input: RTLVerificationEvidenceInput,
        reader: any RTLArtifactReading
    ) throws {
        for (index, evidence) in input.oracleEvidence.enumerated() {
            guard evidence.isAuditable else {
                throw RTLVerificationEvidenceInputArtifactAuditError.oracleEvidenceNotAuditable(
                    index: index,
                    evidenceID: evidence.evidenceID
                )
            }
            try verify([evidence.nativeArtifact, evidence.oracleArtifact], reader: reader)
        }
    }

    private func verify(
        _ artifacts: [ArtifactReference],
        reader: any RTLArtifactReading
    ) throws {
        for artifact in artifacts {
            let artifactID = artifact.artifactID
            do {
                _ = try reader.read(artifact)
            } catch {
                throw RTLVerificationEvidenceInputArtifactAuditError.artifactReadFailed(
                    artifactID: artifactID,
                    path: artifact.path,
                    reason: error.localizedDescription
                )
            }
        }
    }
}
