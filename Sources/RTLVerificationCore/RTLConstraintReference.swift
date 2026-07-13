import Foundation

public struct RTLConstraintReference: Sendable, Hashable, Codable {
    public var artifact: RTLArtifactReference
    public var modeIDs: [String]

    public init(artifact: RTLArtifactReference, modeIDs: [String]) {
        self.artifact = artifact
        self.modeIDs = modeIDs
    }
}
