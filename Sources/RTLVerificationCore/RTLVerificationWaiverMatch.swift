import Foundation

public struct RTLVerificationWaiverMatch: Sendable, Hashable, Codable {
    public let waiverID: String
    public let findingCode: String
    public let findingEntity: String?

    public init(waiverID: String, findingCode: String, findingEntity: String?) {
        self.waiverID = waiverID
        self.findingCode = findingCode
        self.findingEntity = findingEntity
    }
}
