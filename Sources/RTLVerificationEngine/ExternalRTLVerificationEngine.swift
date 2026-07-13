import CDCAnalysis
import FormalEquivalence
import Foundation
import RDCAnalysis
import RTLLint
import RTLVerificationCore

public struct ExternalRTLVerificationEngine: RTLLintExecuting, CDCAnalyzing, RDCAnalyzing, FormalEquivalenceChecking, Sendable {
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
    ) async throws -> RTLVerificationResult {
        guard descriptor.supportedAnalyses.contains(request.analysis) else {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_ANALYSIS_UNSUPPORTED",
                message: "External tool \(descriptor.toolID) does not declare support for \(request.analysis.rawValue).",
                actions: ["select_supported_backend"]
            )
        }
        guard descriptor.supportedProofViews.contains(request.proofView) else {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_PROOF_VIEW_UNSUPPORTED",
                message: "External tool \(descriptor.toolID) does not declare support for proof view \(request.proofView.rawValue).",
                actions: ["select_supported_proof_view", "select_qualified_solver"]
            )
        }
        guard descriptor.qualified else {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_TOOL_UNQUALIFIED",
                message: "The external tool is not process-qualified.",
                actions: ["attach_process_qualification", "select_native_backend"]
            )
        }
        guard descriptor.qualification.satisfies(request.policy.minimumQualification) else {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_QUALIFICATION_INSUFFICIENT",
                message: "The external tool qualification state does not satisfy the requested verification policy.",
                actions: ["attach_qualification_evidence", "select_qualified_backend"]
            )
        }
        guard descriptor.timeoutSeconds.isFinite, descriptor.timeoutSeconds > 0 else {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_TIMEOUT_INVALID",
                message: "The external tool timeout must be a finite value greater than zero.",
                actions: ["correct_tool_timeout", "select_external_backend"]
            )
        }
        let input = try RTLVerificationRequestDigest.encode(request)
        let requestDigest = RTLHasher().sha256(data: input)
        let output: Data
        do {
            let executableURL = URL(fileURLWithPath: descriptor.executablePath)
            let arguments = additionalArguments + ["--analysis", request.analysis.rawValue]
            if let timedRunner = runner as? any RTLExternalToolProcessRunningWithTimeout {
                output = try timedRunner.run(
                    executableURL: executableURL,
                    arguments: arguments,
                    standardInput: input,
                    timeout: descriptor.timeoutSeconds
                )
            } else {
                output = try runner.run(
                    executableURL: executableURL,
                    arguments: arguments,
                    standardInput: input
                )
            }
        } catch let error as RTLVerificationExecutionError {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_TOOL_FAILED",
                message: error.localizedDescription,
                actions: ["inspect_external_tool_log", "retry_run"]
            )
        }
        do {
            var result = try JSONDecoder().decode(
                RTLVerificationResult.self,
                from: output
            )
            guard result.runID == request.runID else {
                throw RTLVerificationExecutionError.invalidArtifact("External result run ID does not match the request.")
            }
            guard result.payload.requestDigest == requestDigest else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result request digest does not match the request."
                )
            }
            guard result.metadata.implementationID == descriptor.toolID else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result implementation ID does not match the tool descriptor."
                )
            }
            guard result.metadata.implementationVersion == descriptor.version else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result implementation version does not match the tool descriptor."
                )
            }
            guard result.metadata.engineID == request.analysis.stageID else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result engine ID does not match the requested analysis."
                )
            }
            guard result.payload.analysis == request.analysis else {
                throw RTLVerificationExecutionError.invalidArtifact("External result analysis does not match the request.")
            }
            guard result.payload.proofView == request.proofView else {
                throw RTLVerificationExecutionError.invalidArtifact("External result proof view does not match the request.")
            }
            guard result.payload.assumptions == request.assumptions else {
                throw RTLVerificationExecutionError.invalidArtifact("External result assumptions do not match the request.")
            }
            guard result.payload.qualification.state <= descriptor.qualification.state else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result qualification exceeds the descriptor qualification state."
                )
            }
            guard result.payload.qualification.implementationID == descriptor.toolID else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result qualification implementation ID does not match the tool descriptor."
                )
            }
            guard result.payload.qualification.implementationVersion == descriptor.version else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result qualification implementation version does not match the tool descriptor."
                )
            }
            if request.proofView.requiresSolver,
               request.policy.requiredProof,
               result.status == .completed,
               result.payload.proofStatus == "proved" {
                guard result.artifacts.contains(where: {
                    Self.isDigestBoundProofArtifact($0)
                }) else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "A solver-backed proof result must retain at least one digest-bound proof artifact."
                    )
                }
            }
            if request.analysis == .formalEquivalence,
               request.policy.requiredProof,
               result.payload.proofStatus != "proved",
               result.status == .completed {
                result.status = .blocked
                result.diagnostics.append(RTLDiagnostic(
                    severity: .error,
                    code: "RTL_EXTERNAL_PROOF_UNPROVEN",
                    message: "The external result did not prove the required equivalence relationship.",
                    suggestedActions: ["inspect_counterexample", "run_qualified_solver"]
                ))
            }
            return result
        } catch let error as RTLVerificationExecutionError {
            throw error
        } catch {
            throw RTLVerificationExecutionError.invalidArtifact(
                "External tool output is not a valid RTL verification result: \(error.localizedDescription)"
            )
        }
    }

    private static func isDigestBoundProofArtifact(
        _ artifact: RTLArtifactReference
    ) -> Bool {
        guard let artifactID = artifact.artifactID,
              !artifactID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifact.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let sha256 = artifact.sha256,
              sha256.count == 64,
              sha256.allSatisfy(\.isHexDigit) else {
            return false
        }
        return true
    }

    private func blockedResult(
        request: RTLVerificationRequest,
        code: String,
        message: String,
        actions: [String]
    ) throws -> RTLVerificationResult {
        let now = Date()
        let diagnostic = RTLDiagnostic(
            severity: .error,
            code: code,
            message: message,
            suggestedActions: actions
        )
        let payload = RTLVerificationPayload(
            findingCount: 0,
            requestDigest: try RTLVerificationRequestDigest.make(request),
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
        return RTLVerificationResult(
            schemaVersion: RTLVerificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: .blocked,
            diagnostics: [diagnostic],
            metadata: RTLExecutionMetadata(
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
