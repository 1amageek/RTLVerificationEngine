import Foundation

public enum RTLVerificationProcessEvidenceBuildError: Error, Sendable, Hashable {
    case invalidInput(String)
    case missingEvidence(kind: RTLVerificationEvidenceRecordKind)
    case invalidEvidence(String)
    case missingArtifact(String)
    case invalidArtifact(String)
    case invalidValidityWindow
    case notValidAt
}

extension RTLVerificationProcessEvidenceBuildError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid RTL process record input: \(message)"
        case .missingEvidence(let kind):
            return "Missing RTL process record evidence of kind \(kind.rawValue)."
        case .invalidEvidence(let evidenceID):
            return "Invalid RTL process record evidence: \(evidenceID)."
        case .missingArtifact(let artifactID):
            return "RTL process record evidence references missing artifact \(artifactID)."
        case .invalidArtifact(let artifactID):
            return "Invalid RTL process record artifact \(artifactID)."
        case .invalidValidityWindow:
            return "RTL process record validity window is invalid."
        case .notValidAt:
            return "RTL process record is not valid at the requested evaluation time."
        }
    }
}
