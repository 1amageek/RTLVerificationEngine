import Foundation

public struct RTLVerificationSourceInput: Sendable, Hashable {
    public var reference: RTLArtifactReference
    public var data: Data

    public init(reference: RTLArtifactReference, data: Data) {
        self.reference = reference
        self.data = data
    }

    public var path: String {
        reference.path
    }
}
