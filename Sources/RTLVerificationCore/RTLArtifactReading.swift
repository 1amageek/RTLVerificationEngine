import Foundation
import XcircuitePackage

public protocol RTLArtifactReading: Sendable {
    func read(_ reference: XcircuiteFileReference) throws -> Data
}
