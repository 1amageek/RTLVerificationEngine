import Foundation

public protocol RTLVerificationProcessEvidenceBuilding: Sendable {
    func build(
        _ request: RTLVerificationProcessEvidenceBuildRequest,
        at date: Date
    ) throws -> RTLVerificationProcessEvidenceBuildResult
}
