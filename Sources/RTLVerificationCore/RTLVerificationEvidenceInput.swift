import Foundation

public struct RTLVerificationEvidenceInput: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var corpusEvaluations: [RTLVerificationCorpusEvaluation]
    public var oracleReports: [RTLVerificationOracleCorrelationReport]
    public var oracleEvidence: [RTLVerificationOracleEvidence]
    public var expectedRequestDigest: String?

    public init(
        corpusEvaluations: [RTLVerificationCorpusEvaluation] = [],
        oracleReports: [RTLVerificationOracleCorrelationReport] = [],
        oracleEvidence: [RTLVerificationOracleEvidence] = [],
        expectedRequestDigest: String? = nil,
        schemaVersion: Int = RTLVerificationEvidenceInput.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.corpusEvaluations = corpusEvaluations
        self.oracleReports = oracleReports
        self.oracleEvidence = oracleEvidence
        self.expectedRequestDigest = expectedRequestDigest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL verification record input schema version \(schemaVersion)."
            )
        }
        self.init(
            corpusEvaluations: try container.decode(
                [RTLVerificationCorpusEvaluation].self,
                forKey: .corpusEvaluations
            ),
            oracleReports: try container.decode(
                [RTLVerificationOracleCorrelationReport].self,
                forKey: .oracleReports
            ),
            oracleEvidence: try container.decode(
                [RTLVerificationOracleEvidence].self,
                forKey: .oracleEvidence
            ),
            expectedRequestDigest: try container.decodeIfPresent(String.self, forKey: .expectedRequestDigest),
            schemaVersion: schemaVersion
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case corpusEvaluations
        case oracleReports
        case oracleEvidence
        case expectedRequestDigest
    }
}
