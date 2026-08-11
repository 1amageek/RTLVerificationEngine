import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation
import TimingCore

public struct RTLVerificationConstraintLoader: Sendable {
    public var reader: any RTLArtifactReading

    public init(reader: any RTLArtifactReading) {
        self.reader = reader
    }

    public func load(
        _ reference: RTLConstraintReference,
        request: RTLVerificationRequest
    ) async throws -> RTLVerificationConstraintContext {
        let binding = try request.requireBinding(for: reference.artifact)
        let data = try await reader.read(binding)
        let modeIDs = reference.modeIDs.isEmpty ? ["default"] : reference.modeIDs
        do {
            let sets = try modeIDs.map { try SDCParser().parse(data, modeID: $0) }
            return RTLVerificationConstraintContext.combine(
                sets,
                sourceArtifact: RTLVerificationSourceArtifact(
                    path: binding.sourcePath,
                    sha256: try SHA256ContentDigester().digest(data: data).hexadecimalValue,
                    byteCount: Int64(data.count),
                    order: 0
                )
            )
        } catch {
            throw RTLVerificationExecutionError.constraintFailed(
                path: binding.sourcePath,
                reason: error.localizedDescription
            )
        }
    }
}
