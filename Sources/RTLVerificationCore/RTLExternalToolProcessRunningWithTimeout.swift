import Foundation

public protocol RTLExternalToolProcessRunningWithTimeout: RTLExternalToolProcessRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data,
        timeout: TimeInterval
    ) throws -> Data
}
