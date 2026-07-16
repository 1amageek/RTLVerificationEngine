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

}
