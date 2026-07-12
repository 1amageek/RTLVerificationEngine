import Foundation

public struct RTLVerificationSourceArtifact: Sendable, Hashable, Codable {
    public var path: String
    public var sha256: String
    public var byteCount: Int64
    public var order: Int

    public init(path: String, sha256: String, byteCount: Int64, order: Int) {
        self.path = path
        self.sha256 = sha256
        self.byteCount = byteCount
        self.order = order
    }
}
