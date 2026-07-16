import Foundation

public enum RTLVerificationEvidenceInputArtifactAuditError: Error, Sendable, Hashable {
    case oracleEvidenceNotAuditable(index: Int, evidenceID: String)
    case artifactReadFailed(artifactID: String, path: String, reason: String)
}

extension RTLVerificationEvidenceInputArtifactAuditError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .oracleEvidenceNotAuditable(let index, let evidenceID):
            return "RTL oracle evidence at index \(index) is not auditable: \(evidenceID)."
        case .artifactReadFailed(let artifactID, let path, let reason):
            return "RTL evidence artifact \(artifactID) at \(path) failed integrity verification: \(reason)"
        }
    }
}
