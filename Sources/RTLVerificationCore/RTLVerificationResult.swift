import Foundation
import CircuiteFoundation

/// RTL verification domain result. This type owns status, diagnostics and
/// payload for RTL analyses without a generic cross-domain result.
public struct RTLVerificationResult: Sendable, Hashable, Codable, ArtifactProducing,
    EvidenceProviding, DiagnosticReporting
{
    public var schemaVersion: Int
    public var runID: String
    public var status: RTLExecutionStatus
    public var rtlDiagnostics: [RTLDiagnostic]
    public var artifacts: [ArtifactReference] {
        didSet {
            evidence = EvidenceManifest(
                id: evidence.id,
                provenance: provenance,
                artifacts: artifacts
            )
        }
    }
    public var provenance: ExecutionProvenance {
        didSet {
            evidence = EvidenceManifest(
                id: evidence.id,
                provenance: provenance,
                artifacts: artifacts
            )
        }
    }
    public var payload: RTLVerificationPayload
    public private(set) var evidence: EvidenceManifest

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case status
        case rtlDiagnostics
        case artifacts
        case provenance
        case payload
        case evidence
    }

    public init(
        schemaVersion: Int,
        runID: String,
        status: RTLExecutionStatus,
        diagnostics: [RTLDiagnostic] = [],
        artifacts: [ArtifactReference] = [],
        provenance: ExecutionProvenance,
        payload: RTLVerificationPayload
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.rtlDiagnostics = diagnostics
        self.artifacts = artifacts
        self.provenance = provenance
        self.payload = payload
        self.evidence = EvidenceManifest(provenance: provenance, artifacts: artifacts)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        runID = try container.decode(String.self, forKey: .runID)
        status = try container.decode(RTLExecutionStatus.self, forKey: .status)
        rtlDiagnostics = try container.decode([RTLDiagnostic].self, forKey: .rtlDiagnostics)
        artifacts = try container.decode([ArtifactReference].self, forKey: .artifacts)
        provenance = try container.decode(ExecutionProvenance.self, forKey: .provenance)
        payload = try container.decode(RTLVerificationPayload.self, forKey: .payload)
        evidence = try container.decode(EvidenceManifest.self, forKey: .evidence)
        guard evidence.provenance == provenance, evidence.artifacts == artifacts else {
            throw DecodingError.dataCorruptedError(
                forKey: .evidence,
                in: container,
                debugDescription: "RTL verification evidence does not match result provenance and artifacts."
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
            do {
                code = try DiagnosticCode(rawValue: "rtl.invalid-diagnostic-code")
            } catch {
                preconditionFailure("The built-in RTL diagnostic code must be valid.")
            }
        }
        let subject: DesignObjectReference?
        let invalidEntityDetail: String?
        if let entity = diagnostic.entity, !entity.isEmpty {
            do {
                subject = try DesignObjectReference(
                    kind: DesignObjectKind(rawValue: "rtl.entity"),
                    identifier: entity
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
