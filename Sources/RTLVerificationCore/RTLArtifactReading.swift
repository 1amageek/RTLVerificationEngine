import Foundation
import CircuiteFoundation

public protocol RTLArtifactReading: Sendable {
    func read(_ binding: RTLArtifactBinding) async throws -> Data
}
