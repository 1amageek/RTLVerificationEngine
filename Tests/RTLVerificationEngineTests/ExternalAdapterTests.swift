import Foundation
import LogicIR
import Testing
import RTLVerificationCore
import RTLVerificationEngine

@Suite("RTL external adapter")
struct ExternalAdapterTests {
    @Test("unqualified external tools are blocked")
    func unqualifiedToolIsBlocked() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-blocked",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
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
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-qualified",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let output = try makeEnvelope(request: request)
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
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-proof-view-mismatch",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .formalEquivalence,
            proofView: .rtlToSynthesized
        )
        var output = try makeEnvelope(
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
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-identity-mismatch",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        var output = try makeEnvelope(request: request)
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
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-timeout",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let output = try JSONEncoder().encode(try makeEnvelope(
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
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-invalid-timeout",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
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

    @Test("external adapter executes a real process and binds the request digest")
    func externalAdapterExecutesRealProcess() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-real-process",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let requestDigest = try RTLVerificationRequestDigest.make(request)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: "rtl-external-adapter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: temporaryDirectory)
            } catch {
                Issue.record("Could not remove external adapter fixture: \(error.localizedDescription)")
            }
        }

        let templateURL = temporaryDirectory.appending(path: "envelope.json")
        let scriptURL = temporaryDirectory.appending(path: "oracle.sh")
        var template = String(
            data: try JSONEncoder().encode(makeEnvelope(request: request, implementationID: "real-tool")),
            encoding: .utf8
        ) ?? ""
        template = template.replacingOccurrences(of: requestDigest, with: "REQUEST_DIGEST")
        try template.write(to: templateURL, atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        set -eu
        input="$(cat)"
        digest="$(printf '%s' "$input" | shasum -a 256 | awk '{print $1}')"
        sed "s/REQUEST_DIGEST/$digest/g" "$1"
        """.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "real-tool",
                executablePath: scriptURL.path,
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true,
                timeoutSeconds: 5
            ),
            additionalArguments: [templateURL.path]
        )

        let result = try await engine.execute(request)

        #expect(result.status == .completed)
        #expect(result.payload.requestDigest == requestDigest)
        #expect(result.metadata.implementationID == "real-tool")
    }

    @Test("external adapter blocks when a real process exceeds its timeout")
    func externalAdapterRealProcessTimeoutBlocks() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-real-timeout",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "real-timeout-tool",
                executablePath: "/bin/sh",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true,
                timeoutSeconds: 0.05
            ),
            additionalArguments: ["-c", "exec sleep 1"]
        )

        let result = try await engine.execute(request)

        #expect(result.status == .blocked)
        #expect(result.diagnostics.first?.code == "RTL_EXTERNAL_TOOL_FAILED")
    }

    @Test("independent oracle executor binds the oracle to the native request")
    func independentOracleExecutorBindsNativeRequest() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-oracle",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let native = try makeEnvelope(
            request: request,
            implementationID: "native-rtl-verification"
        )
        let oracle = try makeEnvelope(
            request: request,
            implementationID: "independent-oracle"
        )
        let executor = ExternalRTLVerificationOracleExecutor(
            descriptor: RTLExternalToolDescriptor(
                toolID: "independent-oracle",
                executablePath: "/qualified/oracle",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true
            ),
            runner: StaticOutputRunner(output: try JSONEncoder().encode(oracle))
        )

        let result = try await executor.execute(request, native: native)

        #expect(result.metadata.implementationID == "independent-oracle")
        #expect(result.payload.requestDigest == native.payload.requestDigest)
    }

    @Test("independent oracle executor rejects self-correlation")
    func independentOracleExecutorRejectsSelfCorrelation() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-oracle-self",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        let native = try makeEnvelope(request: request, implementationID: "same-tool")
        let oracle = try makeEnvelope(request: request, implementationID: "same-tool")
        let executor = ExternalRTLVerificationOracleExecutor(
            descriptor: RTLExternalToolDescriptor(
                toolID: "same-tool",
                executablePath: "/qualified/oracle",
                version: "1",
                supportedAnalyses: [.lint],
                qualified: true
            ),
            runner: StaticOutputRunner(output: try JSONEncoder().encode(oracle))
        )

        do {
            _ = try await executor.execute(request, native: native)
            Issue.record("An oracle must not use the native implementation.")
        } catch let error as RTLVerificationExecutionError {
            #expect(error == .invalidArtifact(
                "Oracle result implementation must be independent from the native implementation."
            ))
        }
    }

    @Test("solver-backed external proof requires a digest-bound proof artifact")
    func solverBackedExternalProofRequiresArtifact() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-solver-artifact",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .formalEquivalence,
            proofView: .rtlToSynthesized
        )
        let output = try makeEnvelope(
            request: request,
            implementationID: "qualified-solver"
        )
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "qualified-solver",
                executablePath: "/qualified/solver",
                version: "1",
                supportedAnalyses: [.formalEquivalence],
                supportedProofViews: [.rtlToSynthesized],
                qualified: true
            ),
            runner: StaticOutputRunner(output: try JSONEncoder().encode(output))
        )

        do {
            _ = try await engine.execute(request)
            Issue.record("A solver-backed proof without a retained certificate must be rejected.")
        } catch let error as RTLVerificationExecutionError {
            #expect(error == .invalidArtifact(
                "A solver-backed proof result must retain at least one digest-bound proof artifact."
            ))
        }
    }

    @Test("solver-backed external proof accepts a digest-bound proof artifact")
    func solverBackedExternalProofAcceptsArtifact() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-solver-artifact-valid",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .formalEquivalence,
            proofView: .rtlToSynthesized
        )
        var output = try makeEnvelope(
            request: request,
            implementationID: "qualified-solver"
        )
        output.artifacts = [makeTestArtifactReference(
            artifactID: "solver-proof-certificate",
            path: "proof/certificate.json",
            kind: .report,
            format: .json,
            role: .output,
            sha256: String(repeating: "a", count: 64),
            byteCount: 1
        )]
        let engine = ExternalRTLVerificationEngine(
            descriptor: RTLExternalToolDescriptor(
                toolID: "qualified-solver",
                executablePath: "/qualified/solver",
                version: "1",
                supportedAnalyses: [.formalEquivalence],
                supportedProofViews: [.rtlToSynthesized],
                qualified: true
            ),
            runner: StaticOutputRunner(output: try JSONEncoder().encode(output))
        )

        let result = try await engine.execute(request)

        #expect(result.status == .completed)
        #expect(result.artifacts.first?.artifactID == "solver-proof-certificate")
    }

    private func makeEnvelope(
        request: RTLVerificationRequest,
        implementationID: String = "qualified-tool",
        implementationVersion: String = "1"
    ) throws -> RTLVerificationResult {
        let now = Date(timeIntervalSince1970: 1)
        return RTLVerificationResult(
            schemaVersion: RTLVerificationRequest.currentSchemaVersion,
            runID: request.runID,
            status: .completed,
            metadata: RTLExecutionMetadata(
                engineID: request.analysis.stageID,
                implementationID: implementationID,
                implementationVersion: implementationVersion,
                startedAt: now,
                completedAt: now
            ),
            payload: RTLVerificationPayload(
                findingCount: 0,
                requestDigest: try RTLVerificationRequestDigest.make(request),
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

    @Test("external results must bind to the exact request digest")
    func externalRequestDigestMismatchIsRejected() async throws {
        let artifact = makeTestArtifactReference(path: "top.sv", kind: .rtl, format: .systemVerilog)
        let request = RTLVerificationRequest(
            runID: "external-request-digest-mismatch",
            inputs: [artifact],
            design: LogicDesignReference(
                artifact: artifact.locator,
                topDesignName: "top",
                designDigest: "digest"
            ),
            analysis: .lint
        )
        var output = try makeEnvelope(request: request)
        output.payload.requestDigest = "wrong-request-digest"
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
            Issue.record("An external result for another request must be rejected.")
        } catch let error as RTLVerificationExecutionError {
            #expect(error == .invalidArtifact("External result request digest does not match the request."))
        }
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
