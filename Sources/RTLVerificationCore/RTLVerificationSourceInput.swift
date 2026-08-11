import CircuiteFoundation
import Foundation

public struct RTLVerificationSourceInput: Sendable, Hashable {
    public var reference: ArtifactReference
    public var path: String
    public var data: Data

    public init(reference: ArtifactReference, path: String, data: Data) {
        self.reference = reference
        self.path = path
        self.data = data
    }
}
