import Foundation

public struct RTLVerificationPolicy: Sendable, Hashable, Codable {
    public var requiredProof: Bool
    public var maximumUnsupportedConstructs: Int
    public var allowWarnings: Bool
    public var seed: UInt64?

    private enum CodingKeys: String, CodingKey {
        case requiredProof
        case maximumUnsupportedConstructs
        case allowWarnings
        case seed
    }

    public init(
        requiredProof: Bool = true,
        maximumUnsupportedConstructs: Int = 0,
        allowWarnings: Bool = true,
        seed: UInt64? = nil
    ) {
        self.requiredProof = requiredProof
        self.maximumUnsupportedConstructs = max(0, maximumUnsupportedConstructs)
        self.allowWarnings = allowWarnings
        self.seed = seed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            requiredProof: try container.decode(Bool.self, forKey: .requiredProof),
            maximumUnsupportedConstructs: try container.decode(Int.self, forKey: .maximumUnsupportedConstructs),
            allowWarnings: try container.decode(Bool.self, forKey: .allowWarnings),
            seed: try container.decodeIfPresent(UInt64.self, forKey: .seed)
        )
    }
}
