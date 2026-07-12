import Foundation

public struct RTLVerificationFrontendOptions: Sendable, Hashable, Codable {
    public var language: String
    public var preprocessorDefines: [String: String]
    public var includeDirectories: [String]
    public var requireTopModule: Bool

    public init(
        language: String = "systemVerilog",
        preprocessorDefines: [String: String] = [:],
        includeDirectories: [String] = [],
        requireTopModule: Bool = true
    ) {
        self.language = language
        self.preprocessorDefines = preprocessorDefines
        self.includeDirectories = includeDirectories
        self.requireTopModule = requireTopModule
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case preprocessorDefines
        case includeDirectories
        case requireTopModule
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            language: try container.decodeIfPresent(String.self, forKey: .language) ?? "systemVerilog",
            preprocessorDefines: try container.decodeIfPresent([String: String].self, forKey: .preprocessorDefines) ?? [:],
            includeDirectories: try container.decodeIfPresent([String].self, forKey: .includeDirectories) ?? [],
            requireTopModule: try container.decodeIfPresent(Bool.self, forKey: .requireTopModule) ?? true
        )
    }
}
