import Foundation

public struct RTLVerificationSourceLocation: Sendable, Hashable, Codable {
    public var path: String
    public var line: Int
    public var column: Int

    public init(path: String, line: Int, column: Int) {
        self.path = path
        self.line = line
        self.column = column
    }
}
