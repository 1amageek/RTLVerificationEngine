import Foundation

public struct RTLVerificationCapability: Sendable, Hashable, Codable {
    public var engineID: String
    public var contractVersion: Int
    public var supportedInputFormats: [ArtifactFormat]
    public var supportedOutputFormats: [ArtifactFormat]
    public var features: [String]
    public var limitations: [String]
    public var record: RTLVerificationEvidenceAssessment

    private enum CodingKeys: String, CodingKey {
        case engineID
        case contractVersion
        case supportedInputFormats
        case supportedOutputFormats
        case features
        case limitations
        case record
    }

    public init(
        engineID: String,
        contractVersion: Int,
        supportedInputFormats: [ArtifactFormat],
        supportedOutputFormats: [ArtifactFormat],
        features: [String],
        limitations: [String],
        record: RTLVerificationEvidenceAssessment = RTLVerificationEvidenceAssessment()
    ) {
        self.engineID = engineID
        self.contractVersion = contractVersion
        self.supportedInputFormats = supportedInputFormats
        self.supportedOutputFormats = supportedOutputFormats
        self.features = features
        self.limitations = limitations
        self.record = record
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            engineID: try container.decode(String.self, forKey: .engineID),
            contractVersion: try container.decode(Int.self, forKey: .contractVersion),
            supportedInputFormats: try container.decode([ArtifactFormat].self, forKey: .supportedInputFormats),
            supportedOutputFormats: try container.decode([ArtifactFormat].self, forKey: .supportedOutputFormats),
            features: try container.decodeIfPresent([String].self, forKey: .features) ?? [],
            limitations: try container.decodeIfPresent([String].self, forKey: .limitations) ?? [],
            record: try container.decodeIfPresent(
                RTLVerificationEvidenceAssessment.self,
                forKey: .record
            ) ?? RTLVerificationEvidenceAssessment()
        )
    }
}
