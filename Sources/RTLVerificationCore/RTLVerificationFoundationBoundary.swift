import Foundation
@_exported import CircuiteFoundation
import XcircuitePackage

/// Errors raised when the legacy RTL result cannot be represented by the
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
/// The domain payload and the Xcircuite result envelope remain available to
/// RTL-specific callers. This value exposes only the cross-domain evidence
/// and diagnostic surfaces and deliberately carries no qualification verdict.
public struct RTLVerificationFoundationEvidence: Sendable, Hashable, Codable, ArtifactProducing,
    EvidenceProviding, DiagnosticReporting
{
    public let evidence: EvidenceManifest
    public let diagnostics: [DesignDiagnostic]

    public var artifacts: [ArtifactReference] { evidence.artifacts }

    public init(
        envelope: XcircuiteEngineResultEnvelope<RTLVerificationPayload>,
        provenance: ExecutionProvenance
    ) throws {
        let producer = try ProducerIdentity(
            kind: .engine,
            identifier: envelope.metadata.implementationID,
            version: envelope.metadata.implementationVersion
        )
        self.evidence = EvidenceManifest(
            provenance: provenance,
            artifacts: try envelope.artifacts.map {
                try Self.makeArtifactReference($0, producer: producer)
            }
        )
        self.diagnostics = try envelope.diagnostics.map(Self.makeDiagnostic)
    }

    private static func makeArtifactReference(
        _ reference: XcircuiteFileReference,
        producer: ProducerIdentity
    ) throws -> ArtifactReference {
        guard let sha256 = reference.sha256, !sha256.isEmpty else {
            throw RTLVerificationFoundationBoundaryError.missingDigest(reference.path)
        }
        guard let byteCount = reference.byteCount else {
            throw RTLVerificationFoundationBoundaryError.missingByteCount(reference.path)
        }
        guard byteCount >= 0 else {
            throw RTLVerificationFoundationBoundaryError.invalidByteCount(reference.path)
        }

        let location: ArtifactLocation
        do {
            if reference.path.hasPrefix("/") {
                location = try ArtifactLocation(fileURL: URL(fileURLWithPath: reference.path))
            } else {
                location = try ArtifactLocation(workspaceRelativePath: reference.path)
            }
        } catch {
            throw RTLVerificationFoundationBoundaryError.invalidArtifactLocation(reference.path)
        }

        let artifactID: ArtifactID
        do {
            artifactID = try ArtifactID(
                rawValue: reference.artifactID ?? "sha256-\(sha256.lowercased())"
            )
        } catch {
            throw RTLVerificationFoundationBoundaryError.invalidArtifactID(
                reference.artifactID ?? reference.path
            )
        }

        return ArtifactReference(
            id: artifactID,
            locator: ArtifactLocator(
                location: location,
                kind: try ArtifactKind(rawValue: reference.kind.rawValue.lowercased()),
                format: try ArtifactFormat(
                    rawValue: reference.format.rawValue
                        .lowercased()
                        .replacingOccurrences(of: "_", with: "-")
                )
            ),
            digest: try ContentDigest(algorithm: .sha256, hexadecimalValue: sha256),
            byteCount: UInt64(byteCount),
            producer: producer
        )
    }

    private static func makeDiagnostic(
        _ diagnostic: XcircuiteEngineDiagnostic
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
