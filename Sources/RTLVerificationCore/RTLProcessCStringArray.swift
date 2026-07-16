import Darwin
import Foundation

final class RTLProcessCStringArray {
    private var pointers: [UnsafeMutablePointer<CChar>?] = []

    init(_ strings: [String]) throws {
        for string in strings {
            guard let pointer = strdup(string) else {
                throw RTLVerificationExecutionError.externalToolFailed(
                    tool: "posix_spawn",
                    reason: "Could not allocate a process argument."
                )
            }
            pointers.append(pointer)
        }
        pointers.append(nil)
    }

    deinit {
        for pointer in pointers {
            free(pointer)
        }
    }

    func withUnsafeMutablePointers<Result>(
        _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
    ) throws -> Result {
        try pointers.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw RTLVerificationExecutionError.externalToolFailed(
                    tool: "posix_spawn",
                    reason: "Could not construct the process argument vector."
                )
            }
            return try body(baseAddress)
        }
    }
}
