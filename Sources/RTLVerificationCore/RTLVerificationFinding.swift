import Foundation

public struct RTLVerificationFinding: Sendable, Hashable, Codable {
    public var severity: RTLDiagnosticSeverity
    public var code: String
    public var message: String
    public var entity: String?
    public var location: RTLVerificationSourceLocation?
    public var suggestedActions: [String]
    public var waived: Bool
    public var waiverID: String?

    public init(
        severity: RTLDiagnosticSeverity,
        code: String,
        message: String,
        entity: String? = nil,
        location: RTLVerificationSourceLocation? = nil,
        suggestedActions: [String] = [],
        waived: Bool = false,
        waiverID: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.entity = entity
        self.location = location
        self.suggestedActions = suggestedActions
        self.waived = waived
        self.waiverID = waiverID
    }

    public var engineDiagnostic: RTLDiagnostic {
        RTLDiagnostic(
            severity: waived ? .warning : severity,
            code: code,
            message: message,
            entity: entity,
            suggestedActions: suggestedActions
        )
    }
}
