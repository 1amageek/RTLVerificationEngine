import Foundation

public protocol RTLVerificationDesignParsing: Sendable {
    func parse(
        data: Data,
        path: String,
        topModuleName: String
    ) throws -> RTLVerificationParsedDesign
}
