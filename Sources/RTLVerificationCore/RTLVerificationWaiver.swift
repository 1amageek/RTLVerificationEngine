import Foundation

public struct RTLVerificationWaiver: Sendable, Hashable, Codable {
    public var waiverID: String
    public var code: String
    public var entity: String?
    public var reason: String

    public init(
        waiverID: String,
        code: String,
        entity: String? = nil,
        reason: String
    ) {
        self.waiverID = waiverID
        self.code = code
        self.entity = entity
        self.reason = reason
    }

    public func applies(to findingCode: String, entity findingEntity: String?) -> Bool {
        guard code == findingCode else { return false }
        guard let entity else { return true }
        return entity == findingEntity
    }
}
