import CircuiteFoundation
import Foundation

public struct RTLVerificationSourceInput: Sendable, Hashable {
    public var reference: ArtifactReference
    public var data: Data

    public init(reference: ArtifactReference, data: Data) {
        self.reference = reference
        self.data = data
    }

    public var path: String {
        reference.path
    }
}
