import Foundation

public struct FoundationRTLExternalToolProcessRunner: RTLExternalToolProcessRunningWithTimeout {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data
    ) throws -> Data {
        try run(
            executableURL: executableURL,
            arguments: arguments,
            standardInput: standardInput,
            timeout: 60
        )
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data,
        timeout: TimeInterval
    ) throws -> Data {
        guard timeout.isFinite, timeout > 0 else {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "External tool timeout must be a finite value greater than zero."
            )
        }
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput
        do {
            try process.run()
        } catch {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: error.localizedDescription
            )
        }
        input.fileHandleForWriting.write(standardInput)
        input.fileHandleForWriting.closeFile()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        guard !process.isRunning else {
            process.terminate()
            process.waitUntilExit()
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "The external tool exceeded the configured timeout of \(timeout) seconds."
            )
        }
        process.waitUntilExit()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "The process exited with a non-zero status."
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return outputData
    }
}
