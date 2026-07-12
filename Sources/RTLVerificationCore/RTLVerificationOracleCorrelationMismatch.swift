import Foundation

public struct RTLVerificationOracleCorrelationMismatch: Sendable, Hashable, Codable {
    public var kind: RTLVerificationOracleCorrelationMismatchKind
    public var expected: String
    public var observed: String
    public var message: String

    public init(
        kind: RTLVerificationOracleCorrelationMismatchKind,
        expected: String,
        observed: String,
        message: String
    ) {
        self.kind = kind
        self.expected = expected
        self.observed = observed
        self.message = message
    }
}
