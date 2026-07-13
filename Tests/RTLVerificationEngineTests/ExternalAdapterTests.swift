import Foundation
import LogicIR
import Testing
import RTLVerificationCore
import RTLVerificationEngine
import XcircuitePackage

@Suite("RTL external adapter")
struct ExternalAdapterTests {
    @Test("unqualified external tools are blocked")
    func unqualifiedToolIsBlocked() async throws {
        let artifact = XcircuiteFileReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-blocked",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "unqualified-tool",
                executablePath: "/missing/tool",
                version: "unknown",
                supportedAnalyses: [.lint]
            ),
            runner: NeverCalledRunner()
        )
        let result = try await engine.execute(request)
        #expect(result.status == .blocked)
        #expect(result.diagnostics.first?.code == "RTL_EXTERNAL_TOOL_UNQUALIFIED")
    }

    @Test("qualified external tools return a validated envelope")
    func qualifiedToolReturnsEnvelope() async throws {
        let artifact = XcircuiteFileReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-qualified",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let output = makeEnvelope(request: request)
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "qualified-tool",
                executablePath: "/qualified/tool",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true
            ),
            runner: StaticOutputRunner(output: try JSONEncoder().encode(output))
        )

        let result = try await engine.execute(request)

        #expect(result.status == .completed)
        #expect(result.metadata.implementationID == "qualified-tool")
    }

    @Test("external proof-view mismatches are rejected")
    func externalProofViewMismatchIsRejected() async throws {
        let artifact = XcircuiteFileReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-proof-view-mismatch",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .formalEquivalence,
            proofView: .rtlToSynthesized
        )
        var output = makeEnvelope(
            request: request,
            implementationID: "qualified-formal-tool"
        )
        output.payload.proofView = .rtlToRtlStructural
        let encoded = try JSONEncoder().encode(output)
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "qualified-formal-tool",
                executablePath: "/qualified/formal-tool",
                version: "1",
                supportedAnalyses: [.formalEquivalence],
                supportedProofViews: [.rtlToSynthesized],
                qualified: true
            ),
            runner: StaticOutputRunner(output: encoded)
        )

        do {
            _ = try await engine.execute(request)
            Issue.record("A proof-view mismatch must be rejected.")
        } catch let error as RTLVerificationExecutionError {
            #expect(error == .invalidArtifact("External result proof view does not match the request."))
        }
    }

    @Test("external result identity is bound to the descriptor")
    func externalResultIdentityMismatchIsRejected() async throws {
        let artifact = XcircuiteFileReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-identity-mismatch",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        var output = makeEnvelope(request: request)
        output.metadata.implementationID = "other-tool"
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "qualified-tool",
                executablePath: "/qualified/tool",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true
            ),
            runner: StaticOutputRunner(output: try JSONEncoder().encode(output))
        )

        do {
            _ = try await engine.execute(request)
            Issue.record("An external result from another implementation must be rejected.")
        } catch let error as RTLVerificationExecutionError {
            #expect(error == .invalidArtifact("External result implementation ID does not match the tool descriptor."))
        }
    }

    @Test("external adapter forwards the configured process timeout")
    func externalTimeoutIsForwarded() async throws {
        let artifact = XcircuiteFileReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-timeout",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let output = try JSONEncoder().encode(makeEnvelope(
            request: request,
            implementationID: "timed-tool"
        ))
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "timed-tool",
                executablePath: "/qualified/timed-tool",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true,
                timeoutSeconds: 0.25
            ),
            runner: TimeoutAssertingRunner(expectedTimeout: 0.25, output: output)
        )

        let result = try await engine.execute(request)

        #expect(result.status == .completed)
    }

    @Test("invalid external timeouts are blocked before execution")
    func invalidExternalTimeoutBlocks() async throws {
        let artifact = XcircuiteFileReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-invalid-timeout",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "invalid-timeout-tool",
                executablePath: "/invalid/timeout-tool",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true,
                timeoutSeconds: 0
            ),
            runner: NeverCalledRunner()
        )

        let result = try await engine.execute(request)

        #expect(result.status == .blocked)
        #expect(result.diagnostics.first?.code == "RTL_EXTERNAL_TIMEOUT_INVALID")
    }

    private func makeEnvelope(
        request: RTLVerificationRequest,
        implementationID: String = "qualified-tool",
        implementationVersion: String = "1"
    ) -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
        let now = Date(timeIntervalSince1970: 1)
        return XcircuiteEngineResultEnvelope(
            schemaVersion: RTLVerificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: .completed,
            metadata: XcircuiteEngineExecutionMetadata(
                engineID: request.analysis.stageID,
                implementationID: implementationID,
                implementationVersion: implementationVersion,
                startedAt: now,
                completedAt: now
            ),
            payload: RTLVerificationPayload(
                findingCount: 0,
                proofStatus: request.analysis == .formalEquivalence ? "proved" : nil,
                analysis: request.analysis,
                qualification: RTLVerificationQualificationReport(
                    implementationID: implementationID,
                    implementationVersion: implementationVersion,
                    state: .unassessed,
                    blockers: []
                ),
                proofView: request.proofView,
                assumptions: request.assumptions
            )
        )
    }

    private struct NeverCalledRunner: RTLExternalToolProcessRunning {
        func run(executableURL: URL, arguments: [String], standardInput: Data) throws -> Data {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "The runner must not be called for an unqualified tool."
            )
        }
    }

    private struct StaticOutputRunner: RTLExternalToolProcessRunning {
        let output: Data

        func run(executableURL: URL, arguments: [String], standardInput: Data) throws -> Data {
            output
        }
    }

    private struct TimeoutAssertingRunner: RTLExternalToolProcessRunningWithTimeout {
        let expectedTimeout: TimeInterval
        let output: Data

        func run(
            executableURL: URL,
            arguments: [String],
            standardInput: Data,
            timeout: TimeInterval
        ) throws -> Data {
            guard timeout == expectedTimeout else {
                throw RTLVerificationExecutionError.externalToolFailed(
                    tool: executableURL.path,
                    reason: "The configured timeout was not forwarded."
                )
            }
            return output
        }

        func run(executableURL: URL, arguments: [String], standardInput: Data) throws -> Data {
            output
        }
    }
}
