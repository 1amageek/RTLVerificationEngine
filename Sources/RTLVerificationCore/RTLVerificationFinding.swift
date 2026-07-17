import Foundation

public struct RTLVerificationFinding: Sendable, Hashable, Codable {
    public var severity: RTLDiagnosticSeverity
    public var code: String
    public var message: String
    public var entity: String?
    public var location: RTLVerificationSourceLocation?
    public var suggestedActions: [String]

    public init(
        severity: RTLDiagnosticSeverity,
        code: String,
        message: String,
        entity: String? = nil,
        location: RTLVerificationSourceLocation? = nil,
        suggestedActions: [String] = []
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.entity = entity
        self.location = location
        self.suggestedActions = suggestedActions
    }

    public var engineDiagnostic: RTLDiagnostic {
        RTLDiagnostic(
            severity: severity,
            code: code,
            message: message,
            entity: entity,
            suggestedActions: suggestedActions
        )
    }
}
