import Foundation

public struct RTLFormalCounterexample: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var runID: String
    public var topModuleName: String
    public var mismatches: [String]
    public var affectedEntities: [String]
    public var proofScope: String
    public var differences: [RTLFormalCounterexampleDifference]

    public init(
        runID: String,
        topModuleName: String,
        mismatches: [String],
        affectedEntities: [String],
        proofScope: String = "canonical-structural-equivalence",
        differences: [RTLFormalCounterexampleDifference] = []
    ) {
        self.schemaVersion = 1
        self.runID = runID
        self.topModuleName = topModuleName
        self.mismatches = mismatches
        self.affectedEntities = affectedEntities
        self.proofScope = proofScope
        self.differences = differences
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case topModuleName
        case mismatches
        case affectedEntities
        case proofScope
        case differences
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            topModuleName: try container.decode(String.self, forKey: .topModuleName),
            mismatches: try container.decode([String].self, forKey: .mismatches),
            affectedEntities: try container.decode([String].self, forKey: .affectedEntities),
            proofScope: try container.decodeIfPresent(String.self, forKey: .proofScope)
                ?? "canonical-structural-equivalence",
            differences: try container.decodeIfPresent(
                [RTLFormalCounterexampleDifference].self,
                forKey: .differences
            ) ?? []
        )
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}
