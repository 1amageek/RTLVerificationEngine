import CircuiteFoundation
import Foundation

public struct RTLVerificationEvidenceInputArtifactAuditor: Sendable {
    public init() {}

    public func audit(
        _ input: RTLVerificationEvidenceInput,
        reader: any RTLArtifactReading
    ) async throws {
        for (index, evidence) in input.oracleEvidence.enumerated() {
            guard evidence.isAuditable else {
                throw RTLVerificationEvidenceInputArtifactAuditError.oracleEvidenceNotAuditable(
                    index: index,
                    evidenceID: evidence.evidenceID
                )
            }
            try await verify(
                [evidence.nativeArtifact, evidence.oracleArtifact],
                reader: reader
            )
        }
    }

    private func verify(
        _ artifacts: [RTLArtifactBinding],
        reader: any RTLArtifactReading
    ) async throws {
        for artifact in artifacts {
            let artifactID = artifact.logicalID
            do {
                _ = try await reader.read(artifact)
            } catch {
                throw RTLVerificationEvidenceInputArtifactAuditError.artifactReadFailed(
                    artifactID: artifactID,
                    path: artifact.sourcePath,
                    reason: error.localizedDescription
                )
            }
        }
    }
}
