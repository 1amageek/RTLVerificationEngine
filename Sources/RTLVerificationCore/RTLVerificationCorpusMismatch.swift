import Foundation

public struct RTLVerificationCorpusMismatch: Sendable, Hashable, Codable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
