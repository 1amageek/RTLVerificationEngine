import CircuiteFoundation
import Foundation

public struct RTLVerificationCorpusRun: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var runID: String
    public var evaluations: [RTLVerificationCorpusEvaluation]
    public var resultArtifacts: [String: RTLArtifactBinding]
    public var summaryArtifact: RTLArtifactBinding?
    public var completedAt: Date

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case evaluations
        case resultArtifacts
        case summaryArtifact
        case completedAt
    }

    public init(
        runID: String,
        evaluations: [RTLVerificationCorpusEvaluation],
        resultArtifacts: [String: RTLArtifactBinding],
        summaryArtifact: RTLArtifactBinding? = nil,
        completedAt: Date = Date(),
        schemaVersion: Int = RTLVerificationCorpusRun.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.evaluations = evaluations.sorted { $0.caseID < $1.caseID }
        self.resultArtifacts = resultArtifacts
        self.summaryArtifact = summaryArtifact
        self.completedAt = completedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL corpus run schema version \(schemaVersion)."
            )
        }
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            evaluations: try container.decode(
                [RTLVerificationCorpusEvaluation].self,
                forKey: .evaluations
            ),
            resultArtifacts: try container.decode(
                [String: RTLArtifactBinding].self,
                forKey: .resultArtifacts
            ),
            summaryArtifact: try container.decodeIfPresent(
                RTLArtifactBinding.self,
                forKey: .summaryArtifact
            ),
            completedAt: try container.decode(Date.self, forKey: .completedAt),
            schemaVersion: schemaVersion
        )
    }

    public var matched: Bool {
        !evaluations.isEmpty && evaluations.allSatisfy(\.matched)
    }
}
