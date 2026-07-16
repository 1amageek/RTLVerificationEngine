import Foundation

public struct RTLVerificationCapability: Sendable, Hashable, Codable {
    public var engineID: String
    public var contractVersion: Int
    public var supportedInputFormats: [ArtifactFormat]
    public var supportedOutputFormats: [ArtifactFormat]
    public var features: [String]
    public var limitations: [String]
    public var record: RTLVerificationEvidenceAssessment

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

}
