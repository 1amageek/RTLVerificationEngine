import Foundation
import CircuiteFoundation

/// Errors raised when an RTL domain result cannot be represented by the
/// Foundation evidence boundary without losing integrity or diagnostic data.
public enum RTLVerificationFoundationBoundaryError: Error, Sendable, Equatable, LocalizedError {
    case missingDigest(String)
    case missingByteCount(String)
    case invalidByteCount(String)
    case invalidArtifactLocation(String)
    case invalidArtifactID(String)
    case invalidDiagnosticCode(String)
    case invalidDiagnosticEntity(String)

    public var errorDescription: String? {
        switch self {
        case .missingDigest(let path):
            "RTL artifact has no SHA-256 digest: \(path)"
        case .missingByteCount(let path):
            "RTL artifact has no byte count: \(path)"
        case .invalidByteCount(let path):
            "RTL artifact has an invalid byte count: \(path)"
        case .invalidArtifactLocation(let path):
            "RTL artifact has an invalid location: \(path)"
        case .invalidArtifactID(let identifier):
            "RTL artifact has an invalid artifact ID: \(identifier)"
        case .invalidDiagnosticCode(let code):
            "RTL diagnostic has an invalid code: \(code)"
        case .invalidDiagnosticEntity(let entity):
            "RTL diagnostic has an invalid entity: \(entity)"
        }
    }
}

/// Foundation evidence projection for an RTL verification execution.
///
/// This value exposes only the cross-domain evidence and diagnostic surfaces
/// and deliberately carries no record verdict.
public struct RTLVerificationFoundationEvidence: Sendable, Hashable, Codable, ArtifactProducing,
    EvidenceProviding, DiagnosticReporting
{
    public let evidence: EvidenceManifest
    public let diagnostics: [DesignDiagnostic]

    public var artifacts: [ArtifactReference] { evidence.artifacts }

    public init(result: RTLVerificationResult) throws {
        self.evidence = EvidenceManifest(
            provenance: result.provenance,
            artifacts: result.artifacts
        )
        self.diagnostics = try result.diagnostics.map(Self.makeDiagnostic)
    }

    private static func makeDiagnostic(
        _ diagnostic: RTLDiagnostic
    ) throws -> DesignDiagnostic {
        let code: DiagnosticCode
        do {
            code = try DiagnosticCode(rawValue: diagnostic.code)
        } catch {
            throw RTLVerificationFoundationBoundaryError.invalidDiagnosticCode(diagnostic.code)
        }

        let subject: DesignObjectReference?
        if let entity = diagnostic.entity, !entity.isEmpty {
            do {
                subject = try DesignObjectReference(
                    kind: try DesignObjectKind(rawValue: "rtl.entity"),
                    identifier: entity
                )
            } catch {
                throw RTLVerificationFoundationBoundaryError.invalidDiagnosticEntity(entity)
            }
        } else {
            subject = nil
        }

        let severity: DiagnosticSeverity
        switch diagnostic.severity {
        case .info:
            severity = .information
        case .warning:
            severity = .warning
        case .error:
            severity = .error
        }

        return DesignDiagnostic(
            code: code,
            severity: severity,
            summary: diagnostic.message,
            subject: subject,
            suggestedActions: diagnostic.suggestedActions.map {
                SuggestedAction(code: "rtl.action", summary: $0)
            }
        )
    }
}

extension RTLVerificationRequest {
    /// Returns the Foundation hierarchy identity for the requested top design.
    public func designObjectReference() throws -> DesignObjectReference {
        try DesignObjectReference(kind: .cell, identifier: design.topDesignName)
    }
}
