import Foundation
import XcircuitePackage

public struct FileSystemRTLArtifactReader: RTLArtifactReading {
    public var projectRoot: URL
    private var verifier: XcircuiteFileReferenceVerifier

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
        self.verifier = XcircuiteFileReferenceVerifier()
    }

    public func read(_ reference: XcircuiteFileReference) throws -> Data {
        let integrity = verifier.verify(reference, projectRoot: projectRoot)
        guard integrity.status == .verified else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: integrity.message
            )
        }
        guard let url = verifier.resolvedURL(for: reference, projectRoot: projectRoot) else {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: "The artifact path is not project-relative."
            )
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: reference.path,
                reason: error.localizedDescription
            )
        }
    }
}
