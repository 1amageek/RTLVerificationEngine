import Foundation

public struct RTLVerificationPreprocessedSource: Sendable, Hashable, Codable {
    public var source: String
    public var unsupportedDirectives: [String]
    public var linePaths: [String]
    public var includedPaths: [String]

    public init(
        source: String,
        unsupportedDirectives: [String] = [],
        linePaths: [String] = [],
        includedPaths: [String] = []
    ) {
        self.source = source
        self.unsupportedDirectives = unsupportedDirectives
        self.linePaths = linePaths
        self.includedPaths = includedPaths
    }
}
