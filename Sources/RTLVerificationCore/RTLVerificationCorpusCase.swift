import Foundation

public struct RTLVerificationCorpusCase: Sendable, Hashable, Codable {
    public var caseID: String
    public var request: RTLVerificationRequest
    public var expectation: RTLVerificationCorpusExpectation

    public init(
        caseID: String,
        request: RTLVerificationRequest,
        expectation: RTLVerificationCorpusExpectation
    ) {
        self.caseID = caseID
        self.request = request
        self.expectation = expectation
    }
}
