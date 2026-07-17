import CircuiteFoundation
import Foundation
import TimingCore

public struct RTLVerificationConstraintLoader: Sendable {
    public var reader: any RTLArtifactReading

    public init(reader: any RTLArtifactReading) {
        self.reader = reader
    }

    public func load(_ reference: RTLConstraintReference) throws -> RTLVerificationConstraintContext {
        let data = try reader.read(reference.artifact)
        let modeIDs = reference.modeIDs.isEmpty ? ["default"] : reference.modeIDs
        do {
            let sets = try modeIDs.map { try SDCParser().parse(data, modeID: $0) }
            return RTLVerificationConstraintContext.combine(
                sets,
                sourceArtifact: RTLVerificationSourceArtifact(
                    path: reference.artifact.path,
                    sha256: try SHA256ContentDigester().digest(data: data).hexadecimalValue,
                    byteCount: Int64(data.count),
                    order: 0
                )
            )
        } catch {
            throw RTLVerificationExecutionError.constraintFailed(
                path: reference.artifact.path,
                reason: error.localizedDescription
            )
        }
    }
}
