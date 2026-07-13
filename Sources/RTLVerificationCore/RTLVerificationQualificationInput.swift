import Foundation

public struct RTLVerificationQualificationInput: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var healthEvidence: [RTLVerificationQualificationEvidence]
    public var corpusEvaluations: [RTLVerificationCorpusEvaluation]
    public var oracleReports: [RTLVerificationOracleCorrelationReport]
    public var oracleEvidence: [RTLVerificationOracleEvidence]
    public var processQualification: RTLVerificationProcessQualificationRecord?
    public var releaseApproval: RTLVerificationQualificationEvidence?
    public var expectedRequestDigest: String?

    public init(
        healthEvidence: [RTLVerificationQualificationEvidence] = [],
        corpusEvaluations: [RTLVerificationCorpusEvaluation] = [],
        oracleReports: [RTLVerificationOracleCorrelationReport] = [],
        oracleEvidence: [RTLVerificationOracleEvidence] = [],
        processQualification: RTLVerificationProcessQualificationRecord? = nil,
        releaseApproval: RTLVerificationQualificationEvidence? = nil,
        expectedRequestDigest: String? = nil,
        schemaVersion: Int = RTLVerificationQualificationInput.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.healthEvidence = healthEvidence
        self.corpusEvaluations = corpusEvaluations
        self.oracleReports = oracleReports
        self.oracleEvidence = oracleEvidence
        self.processQualification = processQualification
        self.releaseApproval = releaseApproval
        self.expectedRequestDigest = expectedRequestDigest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL verification qualification input schema version \(schemaVersion)."
            )
        }
        self.init(
            healthEvidence: try container.decodeIfPresent(
                [RTLVerificationQualificationEvidence].self,
                forKey: .healthEvidence
            ) ?? [],
            corpusEvaluations: try container.decodeIfPresent(
                [RTLVerificationCorpusEvaluation].self,
                forKey: .corpusEvaluations
            ) ?? [],
            oracleReports: try container.decodeIfPresent(
                [RTLVerificationOracleCorrelationReport].self,
                forKey: .oracleReports
            ) ?? [],
            oracleEvidence: try container.decodeIfPresent(
                [RTLVerificationOracleEvidence].self,
                forKey: .oracleEvidence
            ) ?? [],
            processQualification: try container.decodeIfPresent(
                RTLVerificationProcessQualificationRecord.self,
                forKey: .processQualification
            ),
            releaseApproval: try container.decodeIfPresent(
                RTLVerificationQualificationEvidence.self,
                forKey: .releaseApproval
            ),
            expectedRequestDigest: try container.decodeIfPresent(String.self, forKey: .expectedRequestDigest),
            schemaVersion: schemaVersion
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case healthEvidence
        case corpusEvaluations
        case oracleReports
        case oracleEvidence
        case processQualification
        case releaseApproval
        case expectedRequestDigest
    }
}
