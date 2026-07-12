import Foundation
import XcircuitePackage

public struct RTLVerificationSourceInput: Sendable, Hashable {
    public var reference: XcircuiteFileReference
    public var data: Data

    public init(reference: XcircuiteFileReference, data: Data) {
        self.reference = reference
        self.data = data
    }

    public var path: String {
        reference.path
    }
}
