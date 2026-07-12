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

    private struct NeverCalledRunner: RTLExternalToolProcessRunning {
        func run(executableURL: URL, arguments: [String], standardInput: Data) throws -> Data {
            throw RTLVerificationExecutionError.externalToolFailed(
                tool: executableURL.path,
                reason: "The runner must not be called for an unqualified tool."
            )
        }
    }
}
