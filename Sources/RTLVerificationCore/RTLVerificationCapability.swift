import Foundation
import CircuiteFoundation

public struct RTLVerificationCapability: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var engineID: String
    public var schemaVersion: Int
    public var supportedInputFormats: [ArtifactFormat]
    public var supportedOutputFormats: [ArtifactFormat]
    public var features: [String]
    public var limitations: [String]
    public var record: RTLVerificationEvidenceAssessment

    public init(
        engineID: String,
        schemaVersion: Int,
        supportedInputFormats: [ArtifactFormat],
        supportedOutputFormats: [ArtifactFormat],
        features: [String],
        limitations: [String],
        record: RTLVerificationEvidenceAssessment = RTLVerificationEvidenceAssessment()
    ) {
        self.engineID = engineID
        self.schemaVersion = schemaVersion
        self.supportedInputFormats = supportedInputFormats
        self.supportedOutputFormats = supportedOutputFormats
        self.features = features
        self.limitations = limitations
        self.record = record
    }

}
