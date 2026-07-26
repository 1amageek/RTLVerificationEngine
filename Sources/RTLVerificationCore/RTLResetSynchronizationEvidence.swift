import Foundation

public struct RTLResetSynchronizationEvidence: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var resetSignal: String
    public var clockSignal: String
    public var releaseSynchronized: Bool
    public var method: String

    public init(
        resetSignal: String,
        clockSignal: String,
        releaseSynchronized: Bool,
        method: String,
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.resetSignal = resetSignal
        self.clockSignal = clockSignal
        self.releaseSynchronized = releaseSynchronized
        self.method = method
    }

    public func validate(resetSignal: String, clockSignal: String) throws {
        guard schemaVersion == Self.currentSchemaVersion,
              self.resetSignal == resetSignal,
              self.clockSignal == clockSignal,
              releaseSynchronized,
              !method.isEmpty else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Reset synchronization evidence must prove the exact reset/clock domain with a named method."
            )
        }
    }
}
