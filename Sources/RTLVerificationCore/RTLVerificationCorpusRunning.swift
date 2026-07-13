import Foundation

public protocol RTLVerificationCorpusRunning: Sendable {
    func run(
        _ corpus: [RTLVerificationCorpusCase],
        runID: String
    ) async throws -> RTLVerificationCorpusRun
}
