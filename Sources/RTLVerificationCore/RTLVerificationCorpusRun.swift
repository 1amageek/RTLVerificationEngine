import CircuiteFoundation
import Foundation

public struct RTLVerificationCorpusRun: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var evaluations: [RTLVerificationCorpusEvaluation]
    public var resultArtifacts: [String: ArtifactReference]
    public var summaryArtifact: ArtifactReference?
    public var completedAt: Date

    public init(
        runID: String,
        evaluations: [RTLVerificationCorpusEvaluation],
        resultArtifacts: [String: ArtifactReference],
        summaryArtifact: ArtifactReference? = nil,
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

    public var matched: Bool {
        !evaluations.isEmpty && evaluations.allSatisfy(\.matched)
    }
}
