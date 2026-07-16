import Foundation

public enum RTLArtifactStoreError: Error, Sendable, Hashable {
    case invalidPathSegment(String)
    case invalidNamespace(String)
    case rootIsSymbolicLink(String)
    case rootIsNotDirectory(String)
    case pathEscapesRoot(String)
    case symbolicLinkInPath(String)
    case duplicateArtifact(String)
    case conflictingArtifact(String)
    case persistenceFailed(path: String, reason: String)
}

extension RTLArtifactStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPathSegment(let value):
            "RTL artifact path segment is invalid: \(value)"
        case .invalidNamespace(let value):
            "RTL artifact namespace is invalid: \(value)"
        case .rootIsSymbolicLink(let path):
            "RTL artifact root must not be a symbolic link: \(path)"
        case .rootIsNotDirectory(let path):
            "RTL artifact root must be a directory: \(path)"
        case .pathEscapesRoot(let path):
            "RTL artifact path escapes the injected root: \(path)"
        case .symbolicLinkInPath(let path):
            "RTL artifact path contains a symbolic link: \(path)"
        case .duplicateArtifact(let path):
            "RTL artifact already exists with identical content: \(path)"
        case .conflictingArtifact(let path):
            "RTL artifact already exists with different content: \(path)"
        case .persistenceFailed(let path, let reason):
            "RTL artifact persistence failed at \(path): \(reason)"
        }
    }
}
