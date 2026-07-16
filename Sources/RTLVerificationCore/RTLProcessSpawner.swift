import Darwin
import Foundation

enum RTLProcessSpawner {
    static func spawn(
        executableURL: URL,
        arguments: [String],
        inputPipe: Pipe,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) throws -> pid_t {
        var actions: posix_spawn_file_actions_t? = nil
        try requireSuccess(
            posix_spawn_file_actions_init(&actions),
            executableURL: executableURL,
            operation: "posix_spawn_file_actions_init"
        )
        defer { posix_spawn_file_actions_destroy(&actions) }

        var attributes: posix_spawnattr_t? = nil
        try requireSuccess(
            posix_spawnattr_init(&attributes),
            executableURL: executableURL,
            operation: "posix_spawnattr_init"
        )
        defer { posix_spawnattr_destroy(&attributes) }

        try configureFileActions(
            &actions,
            executableURL: executableURL,
            inputPipe: inputPipe,
            outputPipe: outputPipe,
            errorPipe: errorPipe
        )
        try requireSuccess(
            posix_spawnattr_setflags(
                &attributes,
                Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT)
            ),
            executableURL: executableURL,
            operation: "posix_spawnattr_setflags"
        )

        let path = executableURL.path(percentEncoded: false)
        let argumentVector = try RTLProcessCStringArray([path] + arguments)
        var processID = pid_t()
        let result = try path.withCString { executablePointer in
            try argumentVector.withUnsafeMutablePointers { argumentsPointer in
                posix_spawn(
                    &processID,
                    executablePointer,
                    &actions,
                    &attributes,
                    argumentsPointer,
                    Darwin.environ
                )
            }
        }
        try requireSuccess(
            result,
            executableURL: executableURL,
            operation: "posix_spawn"
        )
        return processID
    }

    static func exitCode(from status: Int32) -> Int32 {
        let terminationSignal = status & 0x7f
        if terminationSignal == 0 {
            return (status >> 8) & 0xff
        }
        return 128 + terminationSignal
    }

    private static func configureFileActions(
        _ actions: inout posix_spawn_file_actions_t?,
        executableURL: URL,
        inputPipe: Pipe,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) throws {
        let inputRead = inputPipe.fileHandleForReading.fileDescriptor
        let inputWrite = inputPipe.fileHandleForWriting.fileDescriptor
        let outputRead = outputPipe.fileHandleForReading.fileDescriptor
        let outputWrite = outputPipe.fileHandleForWriting.fileDescriptor
        let errorRead = errorPipe.fileHandleForReading.fileDescriptor
        let errorWrite = errorPipe.fileHandleForWriting.fileDescriptor

        for descriptor in [inputWrite, outputRead, errorRead] {
            try requireSuccess(
                posix_spawn_file_actions_addclose(&actions, descriptor),
                executableURL: executableURL,
                operation: "posix_spawn_file_actions_addclose"
            )
        }
        for (source, destination) in [
            (inputRead, STDIN_FILENO),
            (outputWrite, STDOUT_FILENO),
            (errorWrite, STDERR_FILENO)
        ] {
            try requireSuccess(
                posix_spawn_file_actions_adddup2(&actions, source, destination),
                executableURL: executableURL,
                operation: "posix_spawn_file_actions_adddup2"
            )
            if source != destination {
                try requireSuccess(
                    posix_spawn_file_actions_addclose(&actions, source),
                    executableURL: executableURL,
                    operation: "posix_spawn_file_actions_addclose"
                )
            }
        }
    }

    private static func requireSuccess(
        _ result: Int32,
        executableURL: URL,
        operation: String
    ) throws {
        guard result == 0 else {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path(percentEncoded: false),
                reason: "\(operation) failed with errno \(result): \(String(cString: strerror(result)))"
            )
        }
    }
}
