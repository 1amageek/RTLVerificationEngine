import Foundation

public struct FoundationRTLExternalToolProcessRunner: RTLExternalToolProcessRunning {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data
    ) throws -> Data {
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
