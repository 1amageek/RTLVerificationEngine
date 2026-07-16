import CDCAnalysis
import FormalEquivalence
import Foundation
import RDCAnalysis
import RTLLint
import RTLVerificationCore
import ToolQualification
import CircuiteFoundation

public struct ExternalRTLVerificationEngine: RTLLintExecuting, CDCAnalyzing, RDCAnalyzing, FormalEquivalenceChecking, Sendable {
    public var descriptor: RTLExternalToolDescriptor
    public var runner: any RTLExternalToolProcessRunning
    public var artifactReader: any RTLArtifactReading
    public var additionalArguments: [String]
    public var trustDecision: ToolTrustDecision

    public init(
        descriptor: RTLExternalToolDescriptor,
        trustDecision: ToolTrustDecision,
        runner: any RTLExternalToolProcessRunning = FoundationRTLExternalToolProcessRunner(),
        artifactReader: any RTLArtifactReading = InMemoryRTLArtifactReader(artifacts: [:]),
        additionalArguments: [String] = []
    ) {
        self.descriptor = descriptor
        self.trustDecision = trustDecision
        self.runner = runner
        self.artifactReader = artifactReader
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
        guard trustDecision.status == .eligible,
              trustDecision.toolID == descriptor.toolID else {
            return try blockedResult(
                request: request,
                code: "RTL_EXTERNAL_TOOL_TRUST_REJECTED",
                message: "ToolQualification did not accept the external implementation for this operation.",
                actions: ["evaluate_tool_qualification", "select_native_backend"]
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
                output = try await timedRunner.run(
                    executableURL: executableURL,
                    arguments: arguments,
                    standardInput: input,
                    timeout: descriptor.timeoutSeconds
                )
            } else {
                output = try await runner.run(
                    executableURL: executableURL,
                    arguments: arguments,
                    standardInput: input
                )
            }
        } catch is CancellationError {
            throw CancellationError()
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
            guard result.provenance.producer.build == descriptor.toolID else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result implementation ID does not match the tool descriptor."
                )
            }
            guard result.provenance.producer.version == descriptor.version else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result implementation version does not match the tool descriptor."
                )
            }
            guard result.provenance.producer.identifier == request.analysis.stageID else {
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
            guard result.payload.record.implementationID == descriptor.toolID else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result record implementation ID does not match the tool descriptor."
                )
            }
            guard result.payload.record.implementationVersion == descriptor.version else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "External result record implementation version does not match the tool descriptor."
                )
            }
            if request.proofView.requiresSolver,
               request.policy.requiredProof,
               result.status == .completed,
               result.payload.proofStatus == "proved" {
                let proofArtifactIDs = result.payload.proofArtifactIDs
                guard !proofArtifactIDs.isEmpty,
                      Set(proofArtifactIDs).count == proofArtifactIDs.count else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "A solver-backed proof result must identify at least one unique proof artifact."
                    )
                }
                let proofArtifacts = result.artifacts.filter { artifact in
                    proofArtifactIDs.contains(artifact.id.rawValue)
                }
                guard proofArtifacts.count == proofArtifactIDs.count,
                      proofArtifacts.allSatisfy(Self.isProofArtifact) else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "Every declared proof artifact must be a digest-bound output evidence artifact."
                    )
                }
                for artifact in proofArtifacts {
                    do {
                        _ = try artifactReader.read(artifact)
                    } catch {
                        throw RTLVerificationExecutionError.invalidArtifact(
                            "External proof artifact integrity verification failed for \(artifact.path): \(error.localizedDescription)"
                        )
                    }
                }
            }
            if request.analysis == .formalEquivalence,
               request.policy.requiredProof,
               result.payload.proofStatus != "proved",
               result.status == .completed {
                result.status = .blocked
                result.rtlDiagnostics.append(RTLDiagnostic(
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

    private static func isProofArtifact(
        _ artifact: ArtifactReference
    ) -> Bool {
        let artifactID = artifact.artifactID
        let sha256 = artifact.digest.hexadecimalValue
        guard !artifactID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !artifact.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              artifact.digest.algorithm == .sha256,
              sha256.count == 64,
              sha256.allSatisfy(\.isHexDigit) else {
            return false
        }
        return artifact.locator.role == .output
            && (artifact.locator.kind == .evidence || artifact.locator.kind == .report)
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
            record: RTLVerificationEvidenceAssessment(
                implementationID: descriptor.toolID,
                implementationVersion: descriptor.version
            ),
            proofView: request.proofView,
            assumptions: request.assumptions
        )
        return RTLVerificationResult(
            schemaVersion: RTLVerificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: .blocked,
            diagnostics: [diagnostic],
            provenance: try ExecutionProvenance(
                producer: ProducerIdentity(
                    kind: .tool,
                    identifier: request.analysis.stageID,
                    version: descriptor.version,
                    build: descriptor.toolID
                ),
                inputs: request.inputs + request.referenceInputs,
                invocation: ExecutionInvocation.externalProcess(
                    executable: descriptor.executablePath,
                    arguments: additionalArguments
                ),
                startedAt: now,
                completedAt: now
            ),
            payload: payload
        )
    }
}
