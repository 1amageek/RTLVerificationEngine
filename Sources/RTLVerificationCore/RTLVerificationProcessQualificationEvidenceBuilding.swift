import Foundation

public protocol RTLVerificationProcessQualificationEvidenceBuilding: Sendable {
    func build(
        _ request: RTLVerificationProcessQualificationEvidenceBuildRequest,
        at date: Date
    ) throws -> RTLVerificationProcessQualificationEvidenceBuildResult
}
