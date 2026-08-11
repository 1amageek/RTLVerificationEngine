import CircuiteFoundation
import Foundation

public struct RTLVerificationReport: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var analysis: RTLVerificationAnalysis
    public var status: RTLExecutionStatus
    public var diagnostics: [RTLDiagnostic]
    public var payload: RTLVerificationPayload
    public var inputArtifacts: [ArtifactReference]
    public var generatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case analysis
        case status
        case diagnostics
        case payload
        case inputArtifacts
        case generatedAt
    }

    public init(
        schemaVersion: Int = RTLVerificationReport.currentSchemaVersion,
        runID: String,
        analysis: RTLVerificationAnalysis,
        status: RTLExecutionStatus,
        diagnostics: [RTLDiagnostic],
        payload: RTLVerificationPayload,
        inputArtifacts: [ArtifactReference],
        generatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.analysis = analysis
        self.status = status
        self.diagnostics = diagnostics
        self.payload = payload
        self.inputArtifacts = inputArtifacts
        self.generatedAt = generatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL verification report schema version \(schemaVersion)."
            )
        }
        self.init(
            schemaVersion: schemaVersion,
            runID: try container.decode(String.self, forKey: .runID),
            analysis: try container.decode(RTLVerificationAnalysis.self, forKey: .analysis),
            status: try container.decode(RTLExecutionStatus.self, forKey: .status),
            diagnostics: try container.decode([RTLDiagnostic].self, forKey: .diagnostics),
            payload: try container.decode(RTLVerificationPayload.self, forKey: .payload),
            inputArtifacts: try container.decode(
                [ArtifactReference].self,
                forKey: .inputArtifacts
            ),
            generatedAt: try container.decode(Date.self, forKey: .generatedAt)
        )
    }
}
