import Foundation

public struct RTLFormalCounterexample: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

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
        self.schemaVersion = Self.currentSchemaVersion
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
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL formal counterexample schema version \(schemaVersion)."
            )
        }
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            topModuleName: try container.decode(String.self, forKey: .topModuleName),
            mismatches: try container.decode([String].self, forKey: .mismatches),
            affectedEntities: try container.decode([String].self, forKey: .affectedEntities),
            proofScope: try container.decode(String.self, forKey: .proofScope),
            differences: try container.decode(
                [RTLFormalCounterexampleDifference].self,
                forKey: .differences
            )
        )
    }
}
