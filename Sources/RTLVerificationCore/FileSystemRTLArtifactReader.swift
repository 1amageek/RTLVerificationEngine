import CircuiteFoundation
import Foundation

public struct FileSystemRTLArtifactReader: RTLArtifactReading {
    public var projectRoot: URL
    private var verifier: LocalArtifactVerifier

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
        self.verifier = LocalArtifactVerifier()
    }

    public func read(_ reference: ArtifactReference) throws -> Data {
        let integrity = verifier.verify(reference, relativeTo: projectRoot)
        guard integrity.isVerified else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: integrity.issues.map { String(describing: $0) }.joined(separator: "; ")
            )
        }
        let url = try reference.locator.location.resolvedFileURL(relativeTo: projectRoot)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: error.localizedDescription
            )
        }
    }

    public func read(_ locator: ArtifactLocator) throws -> Data {
        let url: URL
        do {
            url = try locator.location.resolvedFileURL(relativeTo: projectRoot)
        } catch {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: locator.path,
                reason: error.localizedDescription
            )
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: locator.path,
                reason: error.localizedDescription
            )
        }
    }
}
