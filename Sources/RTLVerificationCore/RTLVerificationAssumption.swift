import Foundation

public struct RTLVerificationAssumption: Sendable, Hashable, Codable {
    public var assumptionID: String
    public var statement: String
    public var rationale: String
    public var sourceArtifactID: String?

    public init(
        assumptionID: String,
        statement: String,
        rationale: String,
        sourceArtifactID: String? = nil
    ) {
        self.assumptionID = assumptionID
        self.statement = statement
        self.rationale = rationale
        self.sourceArtifactID = sourceArtifactID
    }
}
