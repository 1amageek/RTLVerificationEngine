import Foundation

public enum RTLDiagnosticSeverity: String, Sendable, Hashable, Codable {
    case info
    case warning
    case error
}

public struct RTLDiagnostic: Sendable, Hashable, Codable {
    public var severity: RTLDiagnosticSeverity
    public var code: String
    public var message: String
    public var entity: String?
    public var suggestedActions: [String]

    public init(
        severity: RTLDiagnosticSeverity,
        code: String,
        message: String,
        entity: String? = nil,
        suggestedActions: [String] = []
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.entity = entity
        self.suggestedActions = suggestedActions
    }
}
