import Foundation

public enum RTLVerificationExecutionError: Error, Sendable, Hashable {
    case invalidRequest(String)
    case artifactReadFailed(path: String, reason: String)
    case artifactWriteFailed(artifactID: String, reason: String)
    case parserFailed(path: String, reason: String)
    case constraintFailed(path: String, reason: String)
    case invalidArtifact(String)
    case externalToolFailed(tool: String, reason: String)
}

extension RTLVerificationExecutionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let reason):
            return "Invalid RTL verification request: \(reason)"
        case .artifactReadFailed(let path, let reason):
            return "Could not read RTL artifact \(path): \(reason)"
        case .artifactWriteFailed(let artifactID, let reason):
            return "Could not write RTL artifact \(artifactID): \(reason)"
        case .parserFailed(let path, let reason):
            return "Could not parse RTL artifact \(path): \(reason)"
        case .constraintFailed(let path, let reason):
            return "Could not parse RTL constraints \(path): \(reason)"
        case .invalidArtifact(let reason):
            return "Invalid RTL artifact: \(reason)"
        case .externalToolFailed(let tool, let reason):
            return "External RTL verification tool \(tool) failed: \(reason)"
        }
    }
}
