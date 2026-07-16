import Darwin
import Foundation

public struct FoundationRTLExternalToolProcessRunner: RTLExternalToolProcessRunningWithTimeout {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data
    ) async throws -> Data {
        try await run(
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
    ) async throws -> Data {
        guard timeout.isFinite, timeout > 0 else {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "External tool timeout must be a finite value greater than zero."
            )
        }

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let collector = RTLProcessOutputCollector()
        installDrainHandlers(outputPipe: outputPipe, errorPipe: errorPipe, collector: collector)

        let processID: pid_t
        do {
            processID = try RTLProcessSpawner.spawn(
                executableURL: executableURL,
                arguments: arguments,
                inputPipe: inputPipe,
                outputPipe: outputPipe,
                errorPipe: errorPipe
            )
        } catch {
            closePipesAfterLaunchFailure(
                inputPipe: inputPipe,
                outputPipe: outputPipe,
                errorPipe: errorPipe
            )
            throw error
        }

        inputPipe.fileHandleForReading.closeFile()
        outputPipe.fileHandleForWriting.closeFile()
        errorPipe.fileHandleForWriting.closeFile()
        let deadline = Date().addingTimeInterval(timeout)

        return try await withTaskCancellationHandler {
            do {
                try await writeStandardInput(
                    standardInput,
                    to: inputPipe.fileHandleForWriting,
                    deadline: deadline,
                    executableURL: executableURL
                )
                inputPipe.fileHandleForWriting.closeFile()
                let status = try await waitForExit(
                    processID: processID,
                    deadline: deadline,
                    executableURL: executableURL
                )
                cleanupDescendants(processID: processID)
                finishDrain(outputPipe: outputPipe, errorPipe: errorPipe, collector: collector)
                let snapshot = collector.snapshot()
                let exitCode = RTLProcessSpawner.exitCode(from: status)
                guard exitCode == 0 else {
                    let message = String(decoding: snapshot.standardError, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    throw RTLVerificationExecutionError.externalToolFailed(
                        tool: executableURL.path,
                        reason: message.isEmpty ? "The process exited with status \(exitCode)." : message
                    )
                }
                return snapshot.standardOutput
            } catch {
                inputPipe.fileHandleForWriting.closeFile()
                terminateProcessGroup(processID: processID)
                reap(processID: processID)
                finishDrain(outputPipe: outputPipe, errorPipe: errorPipe, collector: collector)
                if Task.isCancelled || error is CancellationError {
                    throw CancellationError()
                }
                throw error
            }
        } onCancel: {
            Self.signalProcessGroup(processID: processID, signal: SIGTERM)
        }
    }

    private func installDrainHandlers(
        outputPipe: Pipe,
        errorPipe: Pipe,
        collector: RTLProcessOutputCollector
    ) {
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                collector.markStandardOutputClosed()
            } else {
                collector.appendStandardOutput(data)
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                collector.markStandardErrorClosed()
            } else {
                collector.appendStandardError(data)
            }
        }
    }

    private func writeStandardInput(
        _ data: Data,
        to handle: FileHandle,
        deadline: Date,
        executableURL: URL
    ) async throws {
        guard !data.isEmpty else { return }
        let descriptor = handle.fileDescriptor
        let originalFlags = fcntl(descriptor, F_GETFL)
        guard originalFlags >= 0,
              fcntl(descriptor, F_SETFL, originalFlags | O_NONBLOCK) == 0,
              fcntl(descriptor, F_SETNOSIGPIPE, 1) == 0 else {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "Could not configure nonblocking external tool input."
            )
        }
        defer { _ = fcntl(descriptor, F_SETFL, originalFlags) }

        var offset = 0
        while offset < data.count {
            try Task.checkCancellation()
            guard Date() < deadline else {
                throw RTLVerificationExecutionError.externalToolFailed(
                    tool: executableURL.path,
                    reason: "The external tool exceeded its timeout while receiving input."
                )
            }
            let written = data.withUnsafeBytes { bytes -> Int in
                guard let baseAddress = bytes.baseAddress else { return 0 }
                return Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
            }
            if written > 0 {
                offset += written
                continue
            }
            if written < 0, errno == EINTR { continue }
            if written < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                try await Task.sleep(for: .milliseconds(5))
                continue
            }
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "Could not write external tool input: \(String(cString: strerror(errno)))"
            )
        }
    }

    private func waitForExit(
        processID: pid_t,
        deadline: Date,
        executableURL: URL
    ) async throws -> Int32 {
        var status: Int32 = 0
        while true {
            try Task.checkCancellation()
            let result = waitpid(processID, &status, WNOHANG)
            if result == processID { return status }
            if result == -1, errno == EINTR { continue }
            if result == -1 {
                throw RTLVerificationExecutionError.externalToolFailed(
                    tool: executableURL.path,
                    reason: "Could not wait for the external tool: \(String(cString: strerror(errno)))"
                )
            }
            guard Date() < deadline else {
                throw RTLVerificationExecutionError.externalToolFailed(
                    tool: executableURL.path,
                    reason: "The external tool exceeded the configured timeout."
                )
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func cleanupDescendants(processID: pid_t) {
        guard isProcessGroupAlive(processID) else { return }
        Self.signalProcessGroup(processID: processID, signal: SIGTERM)
        let deadline = Date().addingTimeInterval(0.25)
        while isProcessGroupAlive(processID), Date() < deadline { usleep(10_000) }
        if isProcessGroupAlive(processID) {
            Self.signalProcessGroup(processID: processID, signal: SIGKILL)
        }
    }

    private func terminateProcessGroup(processID: pid_t) {
        guard processID > 0, processID != getpgrp() else { return }
        Self.signalProcessGroup(processID: processID, signal: SIGTERM)
        let deadline = Date().addingTimeInterval(0.25)
        while isProcessGroupAlive(processID), Date() < deadline { usleep(10_000) }
        if isProcessGroupAlive(processID) {
            Self.signalProcessGroup(processID: processID, signal: SIGKILL)
        }
    }

    private static func signalProcessGroup(processID: pid_t, signal: Int32) {
        guard processID > 0, processID != getpgrp() else { return }
        _ = kill(-processID, signal)
    }

    private func isProcessGroupAlive(_ processID: pid_t) -> Bool {
        guard processID > 0, processID != getpgrp() else { return false }
        if kill(-processID, 0) == 0 { return true }
        return errno == EPERM
    }

    private func reap(processID: pid_t) {
        var status: Int32 = 0
        while waitpid(processID, &status, 0) == -1, errno == EINTR {}
    }

    private func finishDrain(
        outputPipe: Pipe,
        errorPipe: Pipe,
        collector: RTLProcessOutputCollector
    ) {
        let deadline = Date().addingTimeInterval(0.5)
        while !collector.streamsClosed, Date() < deadline { usleep(10_000) }
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        appendRemainingData(from: outputPipe.fileHandleForReading, append: collector.appendStandardOutput)
        appendRemainingData(from: errorPipe.fileHandleForReading, append: collector.appendStandardError)
        outputPipe.fileHandleForReading.closeFile()
        errorPipe.fileHandleForReading.closeFile()
    }

    private func appendRemainingData(from handle: FileHandle, append: (Data) -> Void) {
        let descriptor = handle.fileDescriptor
        let originalFlags = fcntl(descriptor, F_GETFL)
        if originalFlags >= 0 { _ = fcntl(descriptor, F_SETFL, originalFlags | O_NONBLOCK) }
        defer { if originalFlags >= 0 { _ = fcntl(descriptor, F_SETFL, originalFlags) } }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
            if count > 0 {
                append(Data(buffer.prefix(count)))
                continue
            }
            if count < 0, errno == EINTR { continue }
            return
        }
    }

    private func closePipesAfterLaunchFailure(
        inputPipe: Pipe,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        inputPipe.fileHandleForReading.closeFile()
        inputPipe.fileHandleForWriting.closeFile()
        outputPipe.fileHandleForReading.closeFile()
        outputPipe.fileHandleForWriting.closeFile()
        errorPipe.fileHandleForReading.closeFile()
        errorPipe.fileHandleForWriting.closeFile()
    }
}
