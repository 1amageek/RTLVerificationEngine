import Foundation
import Synchronization

final class RTLProcessOutputCollector: Sendable {
    private struct State: Sendable {
        var standardOutput = Data()
        var standardError = Data()
        var standardOutputClosed = false
        var standardErrorClosed = false
    }

    private let state = Mutex(State())

    var streamsClosed: Bool {
        state.withLock { $0.standardOutputClosed && $0.standardErrorClosed }
    }

    func appendStandardOutput(_ data: Data) {
        state.withLock { $0.standardOutput.append(data) }
    }

    func appendStandardError(_ data: Data) {
        state.withLock { $0.standardError.append(data) }
    }

    func markStandardOutputClosed() {
        state.withLock { $0.standardOutputClosed = true }
    }

    func markStandardErrorClosed() {
        state.withLock { $0.standardErrorClosed = true }
    }

    func snapshot() -> (standardOutput: Data, standardError: Data) {
        state.withLock { ($0.standardOutput, $0.standardError) }
    }
}
