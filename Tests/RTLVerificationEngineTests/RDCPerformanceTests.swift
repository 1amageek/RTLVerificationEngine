import CircuiteFoundation
import Foundation
import LogicIR
import PowerIntent
import RDCAnalysis
import RTLVerificationCore
import Testing

@Suite("RDC performance")
struct RDCPerformanceTests {
    @Test("indexed reset intent scales across 512 clock domains", .timeLimit(.minutes(1)))
    func indexedResetIntentScales() async throws {
        let domainCount = 512
        let processSource = (0..<domainCount).map { index in
            """
              logic sync_\(index)_1;
              logic sync_\(index)_2;
              always_ff @(posedge clk_\(index) or negedge rst_n) begin
                if (!rst_n) begin
                  sync_\(index)_1 <= 1'b0;
                  sync_\(index)_2 <= 1'b0;
                end else begin
                  sync_\(index)_1 <= 1'b1;
                  sync_\(index)_2 <= sync_\(index)_1;
                end
              end
            """
        }.joined(separator: "\n")
        let source = """
        module top(input logic rst_n);
        \(processSource)
        endmodule
        """
        let rtlData = Data(source.utf8)
        let rtl = makeTestArtifactReference(
            path: "rdc-performance.sv",
            kind: .rtl,
            format: .systemVerilog,
            data: rtlData
        )
        let resetIntent = RTLResetIntent(
            domains: (0..<domainCount).map { index in
                RTLResetIntent.Domain(
                    resetSignal: "rst_n",
                    clockSignal: "clk_\(index)",
                    powerDomainID: "power-\(index)",
                    polarity: .activeLow,
                    assertionMode: .asynchronous,
                    minimumReleaseStages: 2
                )
            }
        )
        let powerIntent = PowerIntentDesign(
            format: .upf,
            domains: (0..<domainCount).map { index in
                PowerDomain(
                    id: "power-\(index)",
                    name: "power-\(index)",
                    elements: ["top/domain-\(index)"]
                )
            }
        )
        let resetData = try JSONEncoder().encode(resetIntent)
        let powerData = try JSONEncoder().encode(powerIntent)
        let resetArtifact = makeTestArtifactReference(
            path: "rdc-performance-reset.json",
            kind: .constraint,
            format: .json,
            data: resetData
        )
        let powerArtifact = makeTestArtifactReference(
            path: "rdc-performance-power.json",
            kind: .powerIntent,
            format: .json,
            data: powerData
        )
        let request = RTLVerificationRequest(
            runID: "rdc-performance",
            inputs: [rtl, resetArtifact, powerArtifact],
            design: LogicDesignReference(
                artifact: rtl,
                topDesignName: "top",
                designDigest: rtl.digest.hexadecimalValue
            ),
            resetIntent: RTLResetIntentReference(artifact: resetArtifact),
            powerIntent: PowerIntentReference(
                artifact: powerArtifact,
                designDigest: rtl.digest.hexadecimalValue
            ),
            analysis: .rdc
        )
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: rtlData,
            resetArtifact.path: resetData,
            powerArtifact.path: powerData,
        ])

        let startedAt = Date()
        let result = try await NativeRDCAnalyzer(reader: reader).execute(request)
        let elapsed = Date().timeIntervalSince(startedAt)

        #expect(result.status == .completed)
        #expect(result.payload.coverage.resetReleaseDomains.count == domainCount)
        #expect(elapsed < 5)
    }
}
