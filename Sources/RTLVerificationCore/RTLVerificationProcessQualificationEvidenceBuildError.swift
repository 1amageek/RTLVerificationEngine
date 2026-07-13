import Foundation

public enum RTLVerificationProcessQualificationEvidenceBuildError: Error, Sendable, Hashable {
    case invalidInput(String)
    case missingEvidence(kind: RTLVerificationQualificationEvidenceKind)
    case invalidEvidence(String)
    case missingArtifact(String)
    case invalidArtifact(String)
    case invalidValidityWindow
    case notValidAt
}

extension RTLVerificationProcessQualificationEvidenceBuildError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid RTL process qualification input: \(message)"
        case .missingEvidence(let kind):
            return "Missing RTL process qualification evidence of kind \(kind.rawValue)."
        case .invalidEvidence(let evidenceID):
            return "Invalid RTL process qualification evidence: \(evidenceID)."
        case .missingArtifact(let artifactID):
            return "RTL process qualification evidence references missing artifact \(artifactID)."
        case .invalidArtifact(let artifactID):
            return "Invalid RTL process qualification artifact \(artifactID)."
        case .invalidValidityWindow:
            return "RTL process qualification validity window is invalid."
        case .notValidAt:
            return "RTL process qualification is not valid at the requested evaluation time."
        }
    }
}
