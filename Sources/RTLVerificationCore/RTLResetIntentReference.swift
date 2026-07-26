import CircuiteFoundation
import Foundation

public struct RTLResetIntentReference: Sendable, Hashable, Codable {
    public var artifact: ArtifactReference

    public init(artifact: ArtifactReference) {
        self.artifact = artifact
    }
}
