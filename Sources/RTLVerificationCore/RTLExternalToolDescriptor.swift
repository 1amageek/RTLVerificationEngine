import Foundation

public struct RTLExternalToolDescriptor: Sendable, Hashable, Codable {
    public var toolID: String
    public var executablePath: String
    public var version: String
    public var supportedAnalyses: [RTLVerificationAnalysis]
    public var supportedProofViews: [RTLVerificationProofView]
    public var qualified: Bool
    public var qualification: RTLVerificationQualificationReport
    public var limitations: [String]

    private enum CodingKeys: String, CodingKey {
        case toolID
        case executablePath
        case version
        case supportedAnalyses
        case supportedProofViews
        case qualified
        case qualification
        case limitations
    }

    public init(
        toolID: String,
        executablePath: String,
        version: String,
        supportedAnalyses: [RTLVerificationAnalysis],
        supportedProofViews: [RTLVerificationProofView] = RTLVerificationProofView.allCases,
        qualified: Bool = false,
        qualification: RTLVerificationQualificationReport = RTLVerificationQualificationReport(),
        limitations: [String] = []
    ) {
        self.toolID = toolID
        self.executablePath = executablePath
        self.version = version
        self.supportedAnalyses = supportedAnalyses
        self.supportedProofViews = supportedProofViews
        self.qualified = qualified
        self.qualification = qualification
        self.limitations = limitations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            toolID: try container.decode(String.self, forKey: .toolID),
            executablePath: try container.decode(String.self, forKey: .executablePath),
            version: try container.decode(String.self, forKey: .version),
            supportedAnalyses: try container.decode([RTLVerificationAnalysis].self, forKey: .supportedAnalyses),
            supportedProofViews: try container.decodeIfPresent(
                [RTLVerificationProofView].self,
                forKey: .supportedProofViews
            ) ?? RTLVerificationProofView.allCases,
            qualified: try container.decodeIfPresent(Bool.self, forKey: .qualified) ?? false,
            qualification: try container.decodeIfPresent(
                RTLVerificationQualificationReport.self,
                forKey: .qualification
            ) ?? RTLVerificationQualificationReport(),
            limitations: try container.decodeIfPresent([String].self, forKey: .limitations) ?? []
        )
    }
}
