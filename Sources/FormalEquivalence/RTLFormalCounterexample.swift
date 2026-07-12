import Foundation

public struct RTLFormalCounterexample: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var topModuleName: String
    public var mismatches: [String]
    public var affectedEntities: [String]
    public var proofScope: String

    public init(
        runID: String,
        topModuleName: String,
        mismatches: [String],
        affectedEntities: [String],
        proofScope: String = "canonical-structural-equivalence"
    ) {
        self.schemaVersion = 1
        self.runID = runID
        self.topModuleName = topModuleName
        self.mismatches = mismatches
        self.affectedEntities = affectedEntities
        self.proofScope = proofScope
    }
}
