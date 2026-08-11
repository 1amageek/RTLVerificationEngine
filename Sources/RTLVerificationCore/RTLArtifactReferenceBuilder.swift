import CircuiteFoundation
import CircuiteFoundationFileSystem
import CircuiteFoundationFoundation
import Foundation

/// Creates verified Foundation references for files in an RTL workspace.
public struct RTLArtifactReferenceBuilder: Sendable {
    public init() {}

    public func reference(
        forProjectRelativePath path: String,
        artifactID: String,
        kind: ArtifactKind,
        format: ArtifactFormat,
        inProjectAt projectRoot: URL
    ) throws -> RTLArtifactBinding {
        let root = projectRoot.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = URL(filePath: path, relativeTo: root)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path == root.path || candidate.path.hasPrefix(rootPath) else {
            throw RTLVerificationExecutionError.invalidRequest(
                "Artifact path escapes project root: \(path)"
            )
        }
        let relativePath = try ArtifactRelativePath(
            segments: path.split(separator: "/").map(String.init)
        )
        let locator = ArtifactLocator(
            location: try ArtifactLocation(workspaceRelativePath: relativePath.stringValue),
            role: .input,
            kind: kind,
            format: format
        )
        let reference = try LocalArtifactReferencer().reference(locator, relativeTo: root)
        return try RTLArtifactBinding(
            logicalID: artifactID,
            reference: reference,
            availability: .local(
                artifactID: reference.id,
                rootID: try ArtifactRootID(rawValue: "rtl-verification-project"),
                relativePath: relativePath
            )
        )
    }

    public func readJSON<T: Decodable>(
        _ type: T.Type,
        named path: String,
        forProjectAt projectRoot: URL
    ) throws -> T {
        let binding = try reference(
            forProjectRelativePath: path,
            artifactID: "rtl-input-\(path.hashValue)",
            kind: .constraints,
            format: .json,
            inProjectAt: projectRoot
        )
        let url = projectRoot.appending(path: try binding.requireLocalRelativePath().stringValue)
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
