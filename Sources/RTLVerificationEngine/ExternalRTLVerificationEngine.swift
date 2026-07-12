import CDCAnalysis
import FormalEquivalence
import Foundation
import RDCAnalysis
import RTLLint
import RTLVerificationCore
import XcircuitePackage

public struct ExternalRTLVerificationEngine: RTLLintExecuting, CDCAnalyzing, RDCAnalyzing, FormalEquivalenceChecking {
    public var descriptor: RTLExternalToolDescriptor
    public var runner: any RTLExternalToolProcessRunning
    public var additionalArguments: [String]

    public init(
        descriptor: RTLExternalToolDescriptor,
        runner: any RTLExternalToolProcessRunning = FoundationRTLExternalToolProcessRunner(),
        additionalArguments: [String] = []
    ) {
        self.descriptor = descriptor
        self.runner = runner
        self.additionalArguments = additionalArguments
    }

    public func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
        guard descriptor.supportedAnalyses.contains(request.analysis) else {
            return blockedEnvelope(
                request: request,
                code: "RTL_EXTERNAL_ANALYSIS_UNSUPPORTED",
                message: "External tool \(descriptor.toolID) does not declare support for \(request.analysis.rawValue).",
                actions: ["select_supported_backend"]
            )
        }
        guard descriptor.supportedProofViews.contains(request.proofView) else {
            return blockedEnvelope(
                request: request,
                code: "RTL_EXTERNAL_PROOF_VIEW_UNSUPPORTED",
                message: "External tool \(descriptor.toolID) does not declare support for proof view \(request.proofView.rawValue).",
                actions: ["select_supported_proof_view", "select_qualified_solver"]
            )
        }
        guard descriptor.qualified else {
            return blockedEnvelope(
                request: request,
                code: "RTL_EXTERNAL_TOOL_UNQUALIFIED",
                message: "The external tool is not process-qualified.",
                actions: ["attach_process_qualification", "select_native_backend"]
            )
        }
        guard descriptor.qualification.satisfies(request.policy.minimumQualification) else {
            return blockedEnvelope(
                request: request,
                code: "RTL_EXTERNAL_QUALIFICATION_INSUFFICIENT",
                message: "The external tool qualification state does not satisfy the requested verification policy.",
                actions: ["attach_qualification_evidence", "select_qualified_backend"]
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let input = try encoder.encode(request)
        let output: Data
        do {
            output = try runner.run(
                executableURL: URL(fileURLWithPath: descriptor.executablePath),
                arguments: additionalArguments + ["--analysis", request.analysis.rawValue],
                standardInput: input
            )
        } catch let error as RTLVerificationExecutionError {
            return blockedEnvelope(
                request: request,
                code: "RTL_EXTERNAL_TOOL_FAILED",
                message: error.localizedDescription,
                actions: ["inspect_external_tool_log", "retry_run"]
            )
        }
        do {
            var envelope = try JSONDecoder().decode(
                XcircuiteEngineResultEnvelope<RTLVerificationPayload>.self,
                from: output
            )
            guard envelope.runID == request.runID else {
                throw RTLVerificationExecutionError.invalidArtifact("External result run ID does not match the request.")
            }
            guard envelope.payload.analysis == request.analysis else {
                throw RTLVerificationExecutionError.invalidArtifact("External result analysis does not match the request.")
            }
            guard envelope.payload.qualification.state <= descriptor.qualification.state else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result qualification exceeds the descriptor qualification state."
                )
            }
            if request.analysis == .formalEquivalence,
               request.policy.requiredProof,
               envelope.payload.proofStatus != "proved",
               envelope.status == .completed {
                envelope.status = .blocked
                envelope.diagnostics.append(XcircuiteEngineDiagnostic(
                    severity: .error,
                    code: "RTL_EXTERNAL_PROOF_UNPROVEN",
                    message: "The external result did not prove the required equivalence relationship.",
                    suggestedActions: ["inspect_counterexample", "run_qualified_solver"]
                ))
            }
            return envelope
        } catch let error as RTLVerificationExecutionError {
            throw error
        } catch {
            throw RTLVerificationExecutionError.invalidArtifact(
                "External tool output is not a valid RTL verification envelope: \(error.localizedDescription)"
            )
        }
    }

    private func blockedEnvelope(
        request: RTLVerificationRequest,
        code: String,
        message: String,
        actions: [String]
    ) -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
        let now = Date()
        let diagnostic = XcircuiteEngineDiagnostic(
            severity: .error,
            code: code,
            message: message,
            suggestedActions: actions
        )
        let payload = RTLVerificationPayload(
            findingCount: 0,
            proofStatus: request.analysis == .formalEquivalence ? "unproven" : nil,
            analysis: request.analysis,
            coverage: RTLVerificationCoverage(
                proofScope: request.proofView.rawValue,
                limitations: [message]
            ),
            qualification: descriptor.qualification,
            proofView: request.proofView,
            assumptions: request.assumptions
        )
        return XcircuiteEngineResultEnvelope(
            schemaVersion: RTLVerificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: .blocked,
            diagnostics: [diagnostic],
            metadata: XcircuiteEngineExecutionMetadata(
                engineID: request.analysis.stageID,
                implementationID: descriptor.toolID,
                implementationVersion: descriptor.version,
                startedAt: now,
                completedAt: now
            ),
            payload: payload
        )
    }
}
