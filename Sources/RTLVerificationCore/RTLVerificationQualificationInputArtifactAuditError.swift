import Foundation

public enum RTLVerificationQualificationInputArtifactAuditError: Error, Sendable, Hashable {
    case processEvidenceNotAuditable(index: Int, evidenceID: String)
    case oracleEvidenceNotAuditable(index: Int, evidenceID: String)
    case artifactReadFailed(artifactID: String, path: String, reason: String)
}

extension RTLVerificationQualificationInputArtifactAuditError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .processEvidenceNotAuditable(let index, let evidenceID):
            return "RTL process qualification evidence at index \(index) is not auditable: \(evidenceID)."
        case .oracleEvidenceNotAuditable(let index, let evidenceID):
            return "RTL oracle evidence at index \(index) is not auditable: \(evidenceID)."
        case .artifactReadFailed(let artifactID, let path, let reason):
            return "RTL qualification artifact \(artifactID) at \(path) failed integrity verification: \(reason)"
        }
    }
}
