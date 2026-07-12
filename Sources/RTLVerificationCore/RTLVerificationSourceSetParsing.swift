import Foundation

public protocol RTLVerificationSourceSetParsing: Sendable {
    func parse(
        sources: [RTLVerificationSourceInput],
        topModuleName: String,
        options: RTLVerificationFrontendOptions
    ) throws -> RTLVerificationParsedDesign
}
