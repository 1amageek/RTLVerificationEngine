import Foundation
import CircuiteFoundation
import LogicIR

public enum RTLVerificationExecutionSupport {
    public static let implementationID = "native-rtl-verification"
    public static let implementationVersion = "1.0.0"

    public static func makeDiagnostic(
        _ error: RTLVerificationExecutionError,
        status: RTLExecutionStatus
    ) -> RTLDiagnostic {
        let code: String
        let actions: [String]
        switch error {
        case .invalidRequest:
            code = "RTL_REQUEST_INVALID"
            actions = ["correct_request"]
        case .artifactReadFailed:
            code = "RTL_INPUT_ARTIFACT_UNAVAILABLE"
            actions = ["verify_artifact_path", "verify_artifact_digest"]
        case .artifactWriteFailed:
            code = "RTL_OUTPUT_ARTIFACT_WRITE_FAILED"
            actions = ["inspect_output_directory", "retry_run"]
        case .parserFailed:
            code = "RTL_PARSE_FAILED"
            actions = ["fix_source_syntax", "select_supported_language_subset"]
        case .constraintFailed:
            code = "RTL_CONSTRAINT_PARSE_FAILED"
            actions = ["fix_sdc_constraints", "verify_constraint_mode", "retry_run"]
        case .invalidArtifact:
            code = "RTL_ARTIFACT_INVALID"
            actions = ["regenerate_artifact", "verify_schema_version"]
        case .externalToolFailed:
            code = "RTL_EXTERNAL_TOOL_FAILED"
            actions = ["inspect_external_tool_log", "verify_tool_qualification", "retry_run"]
        }
        return RTLDiagnostic(
            severity: status == .blocked ? .error : .error,
            code: code,
            message: error.localizedDescription,
            suggestedActions: actions
        )
    }

    public static func applyWaivers(
        _ findings: [RTLVerificationFinding],
        waivers: [RTLVerificationWaiver]
    ) -> (findings: [RTLVerificationFinding], applied: [RTLVerificationWaiver]) {
        var appliedIDs: Set<String> = []
        let updated = findings.map { finding -> RTLVerificationFinding in
            guard let waiver = waivers.first(where: { $0.applies(to: finding.code, entity: finding.entity) }) else {
                return finding
            }
            appliedIDs.insert(waiver.waiverID)
            var result = finding
            result.waived = true
            result.waiverID = waiver.waiverID
            return result
        }
        return (updated, waivers.filter { appliedIDs.contains($0.waiverID) })
    }

    public static func status(
        requested: RTLExecutionStatus,
        findings: [RTLVerificationFinding],
        coverage: RTLVerificationCoverage,
        policy: RTLVerificationPolicy,
        proofStatus: String? = nil,
        assessment: RTLVerificationEvidenceAssessment = RTLVerificationEvidenceAssessment()
    ) -> RTLExecutionStatus {
        guard requested == .completed else { return requested }
        if policy.requiredProof, let proofStatus, proofStatus != "proved" { return .blocked }
        guard coverage.unsupportedConstructs.count <= policy.maximumUnsupportedConstructs else { return .blocked }
        if findings.contains(where: { $0.severity == .error && !$0.waived }) { return .failed }
        if !policy.allowWarnings, findings.contains(where: { $0.severity == .warning && !$0.waived }) { return .failed }
        return .completed
    }

    public static func makePayload(
        request: RTLVerificationRequest,
        findings: [RTLVerificationFinding],
        coverage: RTLVerificationCoverage,
        proofStatus: String?,
        counterexampleArtifactIDs: [String],
        appliedWaivers: [RTLVerificationWaiver],
        assessment: RTLVerificationEvidenceAssessment,
        proofView: RTLVerificationProofView,
        assumptions: [RTLVerificationAssumption]
    ) throws -> RTLVerificationPayload {
        RTLVerificationPayload(
            findingCount: findings.count,
            requestDigest: try RTLVerificationRequestDigest.make(request),
            proofStatus: proofStatus,
            analysis: request.analysis,
            findings: findings,
            coverage: coverage,
            appliedWaivers: appliedWaivers,
            counterexampleArtifactIDs: counterexampleArtifactIDs,
            record: assessment,
            proofView: proofView,
            assumptions: assumptions
        )
    }

    public static func sourceLocation(_ span: LogicSourceSpan?) -> RTLVerificationSourceLocation? {
        guard let span else { return nil }
        return RTLVerificationSourceLocation(
            path: span.start.path,
            line: span.start.line,
            column: span.start.column
        )
    }

    public static func normalizeFindings(_ findings: [RTLVerificationFinding]) -> [RTLVerificationFinding] {
        findings.sorted {
            ($0.entity ?? "", $0.code, $0.message) < ($1.entity ?? "", $1.code, $1.message)
        }
    }

    public static func encodeReport(_ report: RTLVerificationReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(report)
    }

    public static func finalize(
        request: RTLVerificationRequest,
        environment: RTLVerificationEnvironment,
        startedAt: Date,
        requestedStatus: RTLExecutionStatus,
        diagnostics: [RTLDiagnostic],
        analysisResult: RTLVerificationAnalysisResult
    ) async throws -> RTLVerificationResult {
        let waiverResult = applyWaivers(analysisResult.findings, waivers: request.waivers)
        let findings = normalizeFindings(waiverResult.findings)
        let completedAt = Date()
        let assessment = try makeEvidenceAssessment(
            request: request,
            analysisResult: analysisResult,
            checkedAt: completedAt
        )
        let status = status(
            requested: requestedStatus,
            findings: findings,
            coverage: analysisResult.coverage,
            policy: request.policy,
            proofStatus: analysisResult.proofStatus,
            assessment: assessment
        )
        let payload: RTLVerificationPayload
        var artifacts: [ArtifactReference] = []
        var counterexampleArtifactIDs: [String] = []

        if let counterexampleData = analysisResult.counterexampleData,
           let artifactID = analysisResult.counterexampleArtifactID {
            let counterexampleReference = try await environment.writer.persist(
                counterexampleData,
                artifactID: artifactID,
                runID: request.runID
            )
            artifacts.append(counterexampleReference)
            counterexampleArtifactIDs.append(artifactID)
        }

        payload = try makePayload(
            request: request,
            findings: findings,
            coverage: analysisResult.coverage,
            proofStatus: analysisResult.proofStatus,
            counterexampleArtifactIDs: counterexampleArtifactIDs,
            appliedWaivers: waiverResult.applied,
            assessment: assessment,
            proofView: request.proofView,
            assumptions: request.assumptions
        )
        var finalDiagnostics = diagnostics + findings.map(\.engineDiagnostic)
        if status == .blocked,
           analysisResult.coverage.unsupportedConstructs.count > request.policy.maximumUnsupportedConstructs {
            finalDiagnostics.append(RTLDiagnostic(
                severity: .error,
                code: "RTL_UNSUPPORTED_SEMANTICS",
                message: "The requested analysis is blocked because the declared semantic coverage is insufficient.",
                suggestedActions: ["reduce_unsupported_constructs", "select_qualified_external_backend"]
            ))
        }
        let provenance = try ExecutionProvenance(
            producer: ProducerIdentity(
                kind: .engine,
                identifier: request.analysis.stageID,
                version: implementationVersion,
                build: implementationID
            ),
            inputs: uniqueReferences(request.inputs + request.referenceInputs),
            invocation: ExecutionInvocation.inProcess(
                entryPoint: "RTLVerificationExecutionSupport.execute"
            ),
            randomSeed: request.policy.seed,
            startedAt: startedAt,
            completedAt: completedAt
        )
        let report = RTLVerificationReport(
            runID: request.runID,
            analysis: request.analysis,
            status: status,
            diagnostics: finalDiagnostics,
            payload: payload,
            inputArtifacts: uniqueReferences(request.inputs + request.referenceInputs),
            generatedAt: completedAt
        )
        let reportData = try encodeReport(report)
        let reportReference = try await environment.writer.persist(
            reportData,
            artifactID: "rtl-verification-report",
            runID: request.runID
        )
        artifacts.append(reportReference)

        return RTLVerificationResult(
            schemaVersion: RTLVerificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: status,
            diagnostics: finalDiagnostics,
            artifacts: artifacts,
            provenance: provenance,
            payload: payload
        )
    }

    private static func uniqueReferences(_ references: [ArtifactReference]) -> [ArtifactReference] {
        var paths: Set<String> = []
        return references.filter { paths.insert($0.path).inserted }
    }

    private static func makeEvidenceAssessment(
        request: RTLVerificationRequest,
        analysisResult: RTLVerificationAnalysisResult,
        checkedAt: Date
    ) throws -> RTLVerificationEvidenceAssessment {
        guard let input = request.evidenceInput else {
            return analysisResult.record
        }
        return RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: analysisResult.record.implementationID,
            implementationVersion: analysisResult.record.implementationVersion,
            corpusEvaluations: input.corpusEvaluations,
            oracleReports: input.oracleReports,
            oracleEvidence: input.oracleEvidence,
            expectedRequestDigest: input.expectedRequestDigest,
            checkedAt: checkedAt
        )
    }

    public static func blockedResult(
        request: RTLVerificationRequest,
        environment: RTLVerificationEnvironment,
        startedAt: Date,
        error: RTLVerificationExecutionError
    ) async throws -> RTLVerificationResult {
        let diagnostic = makeDiagnostic(error, status: .blocked)
        return try await finalize(
            request: request,
            environment: environment,
            startedAt: startedAt,
            requestedStatus: .blocked,
            diagnostics: [diagnostic],
            analysisResult: RTLVerificationAnalysisResult(
                coverage: RTLVerificationCoverage(
                    proofScope: request.analysis == .formalEquivalence ? "unproven" : "none",
                    limitations: [error.localizedDescription]
                )
            )
        )
    }
}
