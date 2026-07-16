import Foundation

public struct RTLExternalToolDescriptor: Sendable, Hashable, Codable {
    public var toolID: String
    public var executablePath: String
    public var version: String
    public var supportedAnalyses: [RTLVerificationAnalysis]
    public var supportedProofViews: [RTLVerificationProofView]
    public var limitations: [String]
    public var timeoutSeconds: TimeInterval

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

}
