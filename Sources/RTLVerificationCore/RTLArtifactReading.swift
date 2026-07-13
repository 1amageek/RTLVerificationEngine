import Foundation
import CircuiteFoundation

public protocol RTLArtifactReading: Sendable {
    func read(_ reference: RTLArtifactReference) throws -> Data
    func read(_ locator: ArtifactLocator) throws -> Data
}
