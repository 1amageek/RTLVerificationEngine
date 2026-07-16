import Foundation

public protocol RTLExternalToolProcessRunning: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data
    ) async throws -> Data
}
