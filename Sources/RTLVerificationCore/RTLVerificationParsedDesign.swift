import Foundation
import LogicIR

public struct RTLVerificationParsedDesign: Sendable, Hashable, Codable {
    public var design: RTLDesign
    public var sourcePaths: [String]
    public var constructCount: Int
    public var unsupportedConstructs: [String]
    public var sourceArtifacts: [RTLVerificationSourceArtifact]

    public init(
        design: RTLDesign,
        sourcePaths: [String] = [],
        constructCount: Int = 0,
        unsupportedConstructs: [String] = [],
        sourceArtifacts: [RTLVerificationSourceArtifact] = []
    ) {
        self.design = design
        self.sourcePaths = sourcePaths
        self.constructCount = max(0, constructCount)
        self.unsupportedConstructs = Array(Set(unsupportedConstructs)).sorted()
        self.sourceArtifacts = sourceArtifacts
    }

    public var analyzedConstructCount: Int {
        max(0, constructCount - unsupportedConstructs.count)
    }
}
