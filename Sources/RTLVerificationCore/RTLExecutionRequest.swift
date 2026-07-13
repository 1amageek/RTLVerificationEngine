import Foundation

public protocol RTLExecutionRequest: Sendable, Hashable, Codable {
    var schemaVersion: Int { get }
    var runID: String { get }
    var inputs: [RTLArtifactReference] { get }
}
