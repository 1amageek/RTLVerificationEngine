import Foundation
import LogicIR
import Testing
import RTLVerificationCore
import RTLLint
import XcircuitePackage

@Suite("RTL verification retained corpus")
struct FixtureCorpusTests {
    @Test("positive fixture is reproducible")
    func positiveFixture() async throws {
        let source = try fixtureData(named: "positive.sv")
        let reference = XcircuiteFileReference(path: "positive.sv", kind: .rtl, format: .systemVerilog)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: source])
        let request = RTLVerificationRequest(
            runID: "corpus-positive",
            inputs: [reference],
            design: LogicDesignReference(
                artifact: reference,
                topDesignName: "top",
                designDigest: "fixture"
            ),
            analysis: .lint
        )
        let result = try await NativeRTLLintEngine(reader: reader).execute(request)
        #expect(result.status == .completed)
    }

    private func fixtureData(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw RTLVerificationExecutionError.invalidArtifact("Fixture \(name) is not retained in the test bundle.")
        }
        return try Data(contentsOf: url)
    }
}
