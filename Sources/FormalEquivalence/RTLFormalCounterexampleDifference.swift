import Foundation

public struct RTLFormalCounterexampleDifference: Sendable, Hashable, Codable {
    public var kind: RTLFormalCounterexampleDifferenceKind
    public var entity: String
    public var implementationValue: String?
    public var referenceValue: String?
    public var message: String

    public init(
        kind: RTLFormalCounterexampleDifferenceKind,
        entity: String,
        implementationValue: String? = nil,
        referenceValue: String? = nil,
        message: String
    ) {
        self.kind = kind
        self.entity = entity
        self.implementationValue = implementationValue
        self.referenceValue = referenceValue
        self.message = message
    }
}
