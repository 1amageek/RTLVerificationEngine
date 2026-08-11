import Foundation
import CircuiteFoundation
import CircuiteFoundationCrypto

public enum RTLVerificationResultError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
}

/// RTL verification domain result. This type owns status, diagnostics and
/// payload for RTL analyses without a generic cross-domain result.
public struct RTLVerificationResult: Sendable, Hashable, Codable, ArtifactProducing,
    EvidenceProviding, DiagnosticReporting
{
    public static let currentSchemaVersion = RTLVerificationRequest.currentSchemaVersion

    public private(set) var schemaVersion: Int
    public var runID: String
    public var status: RTLExecutionStatus
    public var rtlDiagnostics: [RTLDiagnostic]
    public private(set) var artifactBindings: [RTLArtifactBinding]
    public var artifacts: [ArtifactReference] { artifactBindings.map(\.reference) }
    public private(set) var provenance: ExecutionProvenance
    public var payload: RTLVerificationPayload
    public private(set) var evidence: EvidenceManifest

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case status
        case rtlDiagnostics
        case artifactBindings
        case provenance
        case payload
        case evidence
    }

    public init(
        schemaVersion: Int,
        runID: String,
        status: RTLExecutionStatus,
        diagnostics: [RTLDiagnostic] = [],
        artifactBindings: [RTLArtifactBinding] = [],
        provenance: ExecutionProvenance,
        payload: RTLVerificationPayload
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw RTLVerificationResultError.unsupportedSchemaVersion(schemaVersion)
        }
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.rtlDiagnostics = diagnostics
        self.artifactBindings = artifactBindings
        self.provenance = provenance
        self.payload = payload
        self.evidence = try EvidenceManifest.contentAddressed(
            provenance: provenance,
            artifacts: artifactBindings.map(\.reference),
            digester: SHA256ContentDigester()
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL verification result schema version \(schemaVersion)."
            )
        }
        runID = try container.decode(String.self, forKey: .runID)
        status = try container.decode(RTLExecutionStatus.self, forKey: .status)
        rtlDiagnostics = try container.decode([RTLDiagnostic].self, forKey: .rtlDiagnostics)
        artifactBindings = try container.decode([RTLArtifactBinding].self, forKey: .artifactBindings)
        provenance = try container.decode(ExecutionProvenance.self, forKey: .provenance)
        payload = try container.decode(RTLVerificationPayload.self, forKey: .payload)
        evidence = try container.decode(EvidenceManifest.self, forKey: .evidence)
        let expectedEvidence = try EvidenceManifest.contentAddressed(
            provenance: provenance,
            artifacts: artifactBindings.map(\.reference),
            digester: SHA256ContentDigester()
        )
        guard evidence == expectedEvidence else {
            throw DecodingError.dataCorruptedError(
                forKey: .evidence,
                in: container,
                debugDescription: "RTL verification evidence identity does not match result provenance and artifacts."
            )
        }
    }

    public var diagnostics: [DesignDiagnostic] {
        rtlDiagnostics.map(Self.designDiagnostic)
    }

    private static func designDiagnostic(_ diagnostic: RTLDiagnostic) -> DesignDiagnostic {
        let code: DiagnosticCode
        do {
            code = try DiagnosticCode(rawValue: diagnostic.code)
        } catch {
            code = .trusted("rtl.invalid-diagnostic-code")
        }
        let subject: DesignSubjectReference?
        let invalidEntityDetail: String?
        if let entity = diagnostic.entity, !entity.isEmpty {
            do {
                subject = .path(
                    try DesignPathReference(
                        facetID: DesignFacetID(rawValue: "rtl"),
                        kindID: DesignEntityKindID(rawValue: "entity"),
                        localIdentifier: entity
                    )
                )
                invalidEntityDetail = nil
            } catch {
                subject = nil
                invalidEntityDetail = "Invalid RTL diagnostic entity: \(entity)"
            }
        } else {
            subject = nil
            invalidEntityDetail = nil
        }
        let severity: DiagnosticSeverity
        switch diagnostic.severity {
        case .info: severity = .information
        case .warning: severity = .warning
        case .error: severity = .error
        }
        let invalidCodeDetail = code.rawValue == "rtl.invalid-diagnostic-code"
            ? "Invalid RTL diagnostic code: \(diagnostic.code)"
            : nil
        let detail = [invalidCodeDetail, invalidEntityDetail]
            .compactMap { $0 }
            .joined(separator: "; ")
        return DesignDiagnostic(
            code: code,
            severity: severity,
            summary: diagnostic.message,
            detail: detail.isEmpty ? nil : detail,
            subject: subject,
            suggestedActions: diagnostic.suggestedActions.map {
                SuggestedAction(code: "rtl.action", summary: $0)
            }
        )
    }
}
