import Foundation
import XcircuitePackage

public struct RTLVerificationQualificationInputArtifactAuditor: Sendable {
    public init() {}

    public func audit(
        _ input: RTLVerificationQualificationInput,
        reader: any RTLArtifactReading
    ) throws {
        for (index, evidence) in input.processEvidence.enumerated() {
            guard evidence.isAuditable else {
                throw RTLVerificationQualificationInputArtifactAuditError.processEvidenceNotAuditable(
                    index: index,
                    evidenceID: evidence.evidenceID
                )
            }
            try verify(evidence.artifacts, reader: reader)
        }
        for (index, evidence) in input.oracleEvidence.enumerated() {
            guard evidence.isAuditable else {
                throw RTLVerificationQualificationInputArtifactAuditError.oracleEvidenceNotAuditable(
                    index: index,
                    evidenceID: evidence.evidenceID
                )
            }
            try verify([evidence.nativeArtifact, evidence.oracleArtifact], reader: reader)
        }
    }

    private func verify(
        _ artifacts: [XcircuiteFileReference],
        reader: any RTLArtifactReading
    ) throws {
        for artifact in artifacts {
            let artifactID = artifact.artifactID ?? "<missing-artifact-id>"
            do {
                _ = try reader.read(artifact)
            } catch {
                throw RTLVerificationQualificationInputArtifactAuditError.artifactReadFailed(
                    artifactID: artifactID,
                    path: artifact.path,
                    reason: error.localizedDescription
                )
            }
        }
    }
}
