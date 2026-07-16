import Foundation

public struct RTLExternalToolDescriptor: Sendable, Hashable, Codable {
    public var toolID: String
    public var executablePath: String
    public var version: String
    public var supportedAnalyses: [RTLVerificationAnalysis]
    public var supportedProofViews: [RTLVerificationProofView]
    public var limitations: [String]
    public var timeoutSeconds: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case toolID
        case executablePath
        case version
        case supportedAnalyses
        case supportedProofViews
        case limitations
        case timeoutSeconds
    }

    public init(
        toolID: String,
        executablePath: String,
        version: String,
        supportedAnalyses: [RTLVerificationAnalysis],
        supportedProofViews: [RTLVerificationProofView] = RTLVerificationProofView.allCases,
        limitations: [String] = [],
        timeoutSeconds: TimeInterval = 60
    ) {
        self.toolID = toolID
        self.executablePath = executablePath
        self.version = version
        self.supportedAnalyses = supportedAnalyses
        self.supportedProofViews = supportedProofViews
        self.limitations = limitations
        self.timeoutSeconds = timeoutSeconds
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
            limitations: try container.decodeIfPresent([String].self, forKey: .limitations) ?? [],
            timeoutSeconds: try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 60
        )
    }
}
