import Foundation
import XcircuitePackage

public struct RTLVerificationCapability: Sendable, Hashable, Codable {
    public var engineID: String
    public var contractVersion: Int
    public var supportedInputFormats: [XcircuiteFileFormat]
    public var supportedOutputFormats: [XcircuiteFileFormat]
    public var features: [String]
    public var limitations: [String]
    public var qualification: RTLVerificationQualificationReport

    private enum CodingKeys: String, CodingKey {
        case engineID
        case contractVersion
        case supportedInputFormats
        case supportedOutputFormats
        case features
        case limitations
        case qualification
    }

    public init(
        engineID: String,
        contractVersion: Int,
        supportedInputFormats: [XcircuiteFileFormat],
        supportedOutputFormats: [XcircuiteFileFormat],
        features: [String],
        limitations: [String],
        qualification: RTLVerificationQualificationReport = RTLVerificationQualificationReport()
    ) {
        self.engineID = engineID
        self.contractVersion = contractVersion
        self.supportedInputFormats = supportedInputFormats
        self.supportedOutputFormats = supportedOutputFormats
        self.features = features
        self.limitations = limitations
        self.qualification = qualification
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            engineID: try container.decode(String.self, forKey: .engineID),
            contractVersion: try container.decode(Int.self, forKey: .contractVersion),
            supportedInputFormats: try container.decode([XcircuiteFileFormat].self, forKey: .supportedInputFormats),
            supportedOutputFormats: try container.decode([XcircuiteFileFormat].self, forKey: .supportedOutputFormats),
            features: try container.decodeIfPresent([String].self, forKey: .features) ?? [],
            limitations: try container.decodeIfPresent([String].self, forKey: .limitations) ?? [],
            qualification: try container.decodeIfPresent(
                RTLVerificationQualificationReport.self,
                forKey: .qualification
            ) ?? RTLVerificationQualificationReport()
        )
    }
}
