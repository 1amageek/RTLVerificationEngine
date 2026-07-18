import CircuiteFoundation
import Foundation
import LogicEngineCore
import LogicLowering
import LogicIR
import TimingCore
import Testing
@testable import RTLVerificationCore
@testable import RTLLint
@testable import CDCAnalysis
@testable import RDCAnalysis
@testable import FormalEquivalence
@testable import RTLVerificationEngine

@Suite("RTLVerificationEngine contract")
struct ContractTests {
    @Test("native capability metadata covers every routed analysis")
    func nativeCapabilitiesCoverRoutedAnalyses() {
        let capabilities = RTLVerificationEngine.capabilities
        let routedEngineIDs = Set(RTLVerificationAnalysis.allCases.map(\.stageID))

        #expect(Set(capabilities.map(\.engineID)) == routedEngineIDs)
        #expect(capabilities.allSatisfy {
            $0.schemaVersion == RTLVerificationCapability.currentSchemaVersion
                && !$0.supportedInputFormats.isEmpty
                && !$0.supportedOutputFormats.isEmpty
                && !$0.features.isEmpty
        })
    }

    @Test("lint rule catalog is versioned and repair-oriented")
    func lintRuleCatalog() throws {
        #expect(RTLVerificationLintRuleCatalog.schemaVersion == 1)
        #expect(Set(RTLVerificationLintRuleCatalog.rules.map(\.code)).count == RTLVerificationLintRuleCatalog.rules.count)

        let widthRule = try #require(RTLVerificationLintRuleCatalog.rule(for: "RTL_WIDTH_MISMATCH"))
        #expect(widthRule.severity == .error)
        #expect(widthRule.suggestedActions.contains("resize_expression"))
        #expect(RTLVerificationLintRuleCatalog.rule(for: "unknown-rule") == nil)
    }

    @Test("frontend expands function-like macros with nested arguments")
    func frontendExpandsFunctionLikeMacros() throws {
        let source = """
        `define WIDTH(value) value
        `define SELECT(left, right) ((left) ? (right) : (left))
        module top;
          localparam integer W = `WIDTH(`WIDTH(8));
          wire result = `SELECT((W + 1), (W + 2));
        endmodule
        """

        let preprocessed = try SystemVerilogRTLPreprocessor().preprocess(
            source,
            path: "function-macro.sv",
            options: RTLVerificationFrontendOptions()
        )

        #expect(preprocessed.unsupportedDirectives.isEmpty)
        #expect(preprocessed.source.contains("localparam integer W = 8"))
        #expect(preprocessed.source.contains("wire result = (((W + 1)) ? ((W + 2)) : ((W + 1)))"))
    }

    @Test("frontend reports malformed function-like macro invocations")
    func frontendReportsMalformedFunctionLikeMacroInvocation() throws {
        let source = """
        `define SELECT(left, right) left
        module top;
          wire result = `SELECT(1);
        endmodule
        """

        let preprocessed = try SystemVerilogRTLPreprocessor().preprocess(
            source,
            path: "malformed-function-macro.sv",
            options: RTLVerificationFrontendOptions()
        )

        #expect(preprocessed.unsupportedDirectives == ["define_function_invocation:SELECT"])
    }

    @Test("frontend reports recursive function-like macro expansion")
    func frontendReportsRecursiveFunctionLikeMacroExpansion() throws {
        let source = """
        `define LOOP(value) `LOOP(value)
        module top;
          wire result = `LOOP(1);
        endmodule
        """

        let preprocessed = try SystemVerilogRTLPreprocessor().preprocess(
            source,
            path: "recursive-function-macro.sv",
            options: RTLVerificationFrontendOptions()
        )

        #expect(preprocessed.unsupportedDirectives == ["define_function_recursion:LOOP"])
    }

    @Test("frontend evaluates bounded conditional expressions")
    func frontendEvaluatesConditionalExpressions() throws {
        let source = """
        `define WIDTH 8
        `if (`WIDTH < 8) && defined(WIDTH)
        module wrong;
        endmodule
        `elsif WIDTH == 8
        module selected;
        endmodule
        `else
        module fallback;
        endmodule
        `endif
        """

        let preprocessed = try SystemVerilogRTLPreprocessor().preprocess(
            source,
            path: "conditional-expression.sv",
            options: RTLVerificationFrontendOptions()
        )

        #expect(preprocessed.unsupportedDirectives.isEmpty)
        #expect(preprocessed.source.contains("module selected;"))
        #expect(!preprocessed.source.contains("module wrong;"))
        #expect(!preprocessed.source.contains("module fallback;"))
    }

    @Test("frontend reports unsupported conditional expressions")
    func frontendReportsUnsupportedConditionalExpressions() throws {
        let source = """
        `if 8 >> 1
        module unsupported;
        endmodule
        `else
        module fallback;
        endmodule
        `endif
        """

        let preprocessed = try SystemVerilogRTLPreprocessor().preprocess(
            source,
            path: "unsupported-conditional-expression.sv",
            options: RTLVerificationFrontendOptions()
        )

        #expect(preprocessed.unsupportedDirectives == ["conditional_expression:8 >> 1"])
        #expect(preprocessed.source.contains("module fallback;"))
    }

    @Test("frontend rejects an unknown requested top module")
    func frontendRejectsUnknownTopModule() {
        let source = Data("module top; endmodule".utf8)

        #expect(throws: RTLVerificationExecutionError.self) {
            try SystemVerilogRTLParser().parse(
                data: source,
                path: "top.sv",
                topModuleName: "missing"
            )
        }
    }

    @Test("frontend policy can select the first module when top selection is optional")
    func frontendCanSelectFirstModuleWhenOptional() throws {
        let source = Data("module first; endmodule\nmodule second; endmodule".utf8)
        let parsed = try SystemVerilogRTLParser().parse(
            data: source,
            path: "top.sv",
            topModuleName: "",
            options: RTLVerificationFrontendOptions(requireTopModule: false)
        )

        #expect(parsed.design.topModuleName == "first")
    }

    @Test("canonical frontend retains parameters and case statements")
    func canonicalFrontendRetainsStructuredSystemVerilog() throws {
        let source = Data("""
        module top #(parameter WIDTH = 8) (
            input logic [WIDTH-1:0] d,
            input logic select,
            output logic [WIDTH-1:0] q
        );
            always_comb begin
                case (select)
                    1'b0: q = d;
                    default: q = '0;
                endcase
            end
        endmodule
        """.utf8)

        let parsed = try SystemVerilogRTLParser().parse(
            data: source,
            path: "structured.sv",
            topModuleName: "top"
        )

        let module = try #require(parsed.design.modules.first)
        #expect(module.parameters.first?.value == 8)
        #expect(module.ports.first(where: { $0.name == "q" })?.range?.width == 8)
        #expect(module.processes.first?.statements.contains { statement in
            if case .block(let statements) = statement {
                return statements.contains { child in
                    if case .typedCaseStatement = child { return true }
                    return false
                }
            }
            return false
        } == true)
        #expect(parsed.unsupportedConstructs.isEmpty)
    }

    @Test("canonical frontend flattens connected hierarchy")
    func canonicalFrontendFlattensConnectedHierarchy() throws {
        let source = Data("""
        module leaf(input logic a, output logic y);
            assign y = a;
        endmodule
        module top(input logic a, output logic y);
            logic child_y;
            leaf u_leaf(.a(a), .y(child_y));
            assign y = child_y;
        endmodule
        """.utf8)

        let parsed = try SystemVerilogRTLParser().parse(
            data: source,
            path: "hierarchy.sv",
            topModuleName: "top"
        )

        #expect(parsed.design.modules.count == 1)
        #expect(parsed.design.modules.first?.instances.isEmpty == true)
        #expect(parsed.design.modules.first?.assignments.count == 3)
        #expect(parsed.design.modules.first?.signals.contains { $0.name == "u_leaf__y" } == true)
    }

    @Test("canonical frontend resolves parameterized hierarchy widths")
    func canonicalFrontendResolvesParameterizedHierarchyWidths() throws {
        let source = Data("""
        module leaf #(parameter WIDTH = 1) (
            input logic [WIDTH-1:0] a,
            output logic [WIDTH-1:0] y
        );
            assign y = a;
        endmodule
        module top(input logic [3:0] a, output logic [3:0] y);
            leaf #(.WIDTH(4)) u_leaf(.a(a), .y(y));
        endmodule
        """.utf8)

        let parsed = try SystemVerilogRTLParser().parse(
            data: source,
            path: "parameterized-hierarchy.sv",
            topModuleName: "top"
        )

        let module = try #require(parsed.design.modules.first)
        #expect(parsed.design.modules.count == 1)
        #expect(module.instances.isEmpty)
        #expect(module.ports.first(where: { $0.name == "y" })?.range?.width == 4)
        #expect(module.signals.first(where: { $0.name == "u_leaf__y" })?.range?.width == 4)
        #expect(module.assignments.contains {
            if case .identifier(let target) = $0.target {
                return target == "u_leaf__y"
            }
            return false
        } == true)
        #expect(parsed.unsupportedConstructs.isEmpty)
    }

    @Test("request and payload round trip")
    func requestAndPayloadRoundTrip() throws {
        let reference = makeTestArtifactReference(
            path: "rtl/top.sv",
            kind: .rtl,
            format: .systemVerilog
        )
        let request = RTLVerificationRequest(
            runID: "run-001",
            inputs: [reference],
            design: LogicDesignReference(
                artifact: reference,
                topDesignName: "top",
                designDigest: "design-digest"
            ),
            analysis: .cdc,
            policy: RTLVerificationPolicy(maximumUnsupportedConstructs: 0),
            waivers: [RTLVerificationWaiver(
                waiverID: "waiver-001",
                code: "CDC_UNSAFE_CROSSING",
                reason: "Reviewed by design owner."
            )]
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(RTLVerificationRequest.self, from: data)
        #expect(decoded == request)

        let payload = RTLVerificationPayload(
            findingCount: 1,
            proofStatus: "unproven",
            analysis: .cdc,
            findings: [RTLVerificationFinding(
                severity: .error,
                code: "CDC_UNSAFE_CROSSING",
                message: "Crossing requires synchronization.",
                entity: "top.q"
            )],
            coverage: RTLVerificationCoverage(
                clockDomains: ["clk"],
                resetReleaseDomains: ["rst_n@clk"]
            ),
            waiverMatches: [RTLVerificationWaiverMatch(
                waiverID: "waiver-001",
                findingCode: "CDC_UNSAFE_CROSSING",
                findingEntity: "top.q"
            )],
            counterexampleArtifactIDs: [],
            reportVersion: 1
        )
        #expect(try JSONDecoder().decode(RTLVerificationPayload.self, from: JSONEncoder().encode(payload)) == payload)
    }

    @Test("native lint analyzes a positive fixture", .timeLimit(.minutes(1)))
    func nativeLintPositiveFixture() async throws {
        let source = """
        module top(input logic clk, input logic rst_n, input logic async_in, output logic q);
          logic sync1;
          logic sync2;
          always_ff @(posedge clk or negedge rst_n) begin
            sync1 <= async_in;
            sync2 <= sync1;
          end
          assign q = sync2;
        endmodule
        """
        let reference = makeReference(path: "top.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let engine = NativeRTLLintEngine(reader: reader)
        let envelope = try await engine.execute(makeRequest(reference: reference, analysis: .lint))
        #expect(envelope.status == .completed)
        #expect(envelope.payload.findings.isEmpty)
        #expect(envelope.payload.coverage.analyzedConstructs > 0)
        #expect(envelope.artifacts.count == 1)
    }

    @Test("native lint retains negative findings and reports scoped waiver matches", .timeLimit(.minutes(1)))
    func nativeLintNegativeFixture() async throws {
        let source = """
        module top(input logic a, input logic b, output logic [7:0] q);
          logic x;
          assign x = a;
          assign x = b;
          assign q = a;
        endmodule
        """
        let reference = makeReference(path: "negative.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let waiver = RTLVerificationWaiver(
            waiverID: "waiver-width",
            code: "RTL_WIDTH_MISMATCH",
            entity: "top.q",
            reason: "Intentional extension documented in the design review."
        )
        let request = makeRequest(reference: reference, analysis: .lint, waivers: [waiver])
        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)
        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "RTL_MULTIPLE_DRIVER" })
        #expect(envelope.payload.findings.contains { $0.code == "RTL_WIDTH_MISMATCH" })
        #expect(envelope.payload.waiverMatches == [RTLVerificationWaiverMatch(
            waiverID: waiver.waiverID,
            findingCode: "RTL_WIDTH_MISMATCH",
            findingEntity: "top.q"
        )])
    }

    @Test("CDC blocks an unsynchronized asynchronous input", .timeLimit(.minutes(1)))
    func cdcNegativeFixture() async throws {
        let source = """
        module top(input logic clk, input logic async_in, output logic q);
          always_ff @(posedge clk) begin
            q <= async_in;
          end
        endmodule
        """
        let reference = makeReference(path: "cdc-negative.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let envelope = try await NativeCDCAnalyzer(reader: reader).execute(makeRequest(reference: reference, analysis: .cdc))
        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "CDC_ASYNCHRONOUS_INPUT" })
    }

    @Test("CDC resolves source domains independently of process order", .timeLimit(.minutes(1)))
    func cdcResolvesSourceDomainBeforeDestinationOrder() async throws {
        let source = """
        module top(input logic src_clk, input logic dst_clk, input logic async_in, output logic q);
          logic source_state;
          always_ff @(posedge dst_clk) begin
            q <= source_state;
          end
          always_ff @(posedge src_clk) begin
            source_state <= async_in;
          end
        endmodule
        """
        let reference = makeReference(path: "cdc-order.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let envelope = try await NativeCDCAnalyzer(reader: reader).execute(
            makeRequest(reference: reference, analysis: .cdc)
        )

        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "CDC_UNSAFE_CROSSING" })
    }

    @Test("RDC identifies reset domains", .timeLimit(.minutes(1)))
    func rdcFixture() async throws {
        let source = """
        module top(input logic clk, input logic rst_n, output logic q);
          always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) q <= 1'b0;
            else q <= 1'b1;
          end
        endmodule
        """
        let reference = makeReference(path: "rdc.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(makeRequest(reference: reference, analysis: .rdc))
        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.resetDomains == ["rst_n@clk"])
    }

    @Test("RDC retains constraint provenance and clock coverage", .timeLimit(.minutes(1)))
    func rdcProjectsConstraints() async throws {
        let source = """
        module top(input logic clk, input logic rst_n, output logic q);
          always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) q <= 1'b0;
            else q <= 1'b1;
          end
        endmodule
        """
        let constraintData = Data("create_clock -name clk -period 10 [get_ports clk]".utf8)
        let rtl = makeReference(path: "rdc-constrained.sv", format: .systemVerilog, data: Data(source.utf8))
        let sdc = makeTestArtifactReference(path: "rdc.sdc", kind: .constraint, format: .sdc, data: constraintData)
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: Data(source.utf8),
            sdc.path: constraintData
        ])
        var request = makeRequest(
            reference: rtl,
            analysis: .rdc,
            constraints: RTLConstraintReference(artifact: sdc, modeIDs: ["reset-signoff"])
        )
        request.inputs.append(sdc)

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.constraintModes == ["reset-signoff"])
        #expect(envelope.payload.coverage.constrainedClockDomains == ["clk"])
        #expect(envelope.payload.coverage.sourceArtifacts.contains { $0.path == "rdc.sdc" })
    }

    @Test("RDC blocks an unconstrained reset-process clock", .timeLimit(.minutes(1)))
    func rdcBlocksUnconstrainedClock() async throws {
        let source = """
        module top(input logic aux_clk, input logic rst_n, output logic q);
          always_ff @(posedge aux_clk or negedge rst_n) begin
            if (!rst_n) q <= 1'b0;
            else q <= 1'b1;
          end
        endmodule
        """
        let constraintData = Data("create_clock -name clk -period 10 [get_ports clk]".utf8)
        let rtl = makeReference(path: "rdc-unconstrained.sv", format: .systemVerilog, data: Data(source.utf8))
        let sdc = makeTestArtifactReference(path: "rdc-unconstrained.sdc", kind: .constraint, format: .sdc, data: constraintData)
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: Data(source.utf8),
            sdc.path: constraintData
        ])
        var request = makeRequest(
            reference: rtl,
            analysis: .rdc,
            constraints: RTLConstraintReference(artifact: sdc, modeIDs: ["reset-signoff"])
        )
        request.inputs.append(sdc)

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(request)

        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "RDC_CLOCK_UNCONSTRAINED" })
    }

    @Test("RDC records recognized reset release synchronizers across clock domains", .timeLimit(.minutes(1)))
    func rdcRecognizesResetReleaseSynchronizers() async throws {
        let source = """
        module top(input logic clk_a, input logic clk_b, input logic rst_n, output logic q_a, output logic q_b);
          logic a_sync1;
          logic a_sync2;
          logic a_direct;
          logic b_sync1;
          logic b_sync2;
          always_ff @(posedge clk_a or negedge rst_n) begin
            if (!rst_n) begin
              a_sync1 <= 1'b0;
              a_sync2 <= 1'b0;
            end else begin
              a_sync1 <= 1'b1;
              a_sync2 <= a_sync1;
            end
          end
          always_ff @(posedge clk_b or negedge rst_n) begin
            if (!rst_n) begin
              b_sync1 <= 1'b0;
              b_sync2 <= 1'b0;
            end else begin
              b_sync1 <= 1'b1;
              b_sync2 <= b_sync1;
            end
          end
          assign q_a = a_sync2;
          assign q_b = b_sync2;
        endmodule
        """
        let reference = makeReference(path: "rdc-reset-sync.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(
            makeRequest(reference: reference, analysis: .rdc)
        )

        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.resetReleaseDomains == ["rst_n@clk_a", "rst_n@clk_b"])
        #expect(!envelope.payload.findings.contains { $0.code == "RDC_UNSAFE_RESET_CROSSING" })
    }

    @Test("RDC does not treat a mixed reset domain as synchronized", .timeLimit(.minutes(1)))
    func rdcRejectsMixedResetDomain() async throws {
        let source = """
        module top(input logic clk_a, input logic clk_b, input logic rst_n, output logic q_a, output logic q_b);
          logic a_sync1;
          logic a_sync2;
          logic b_sync1;
          logic b_sync2;
          always_ff @(posedge clk_a or negedge rst_n) begin
            if (!rst_n) begin
              a_sync1 <= 1'b0;
              a_sync2 <= 1'b0;
            end else begin
              a_sync1 <= 1'b1;
              a_sync2 <= a_sync1;
            end
          end
          always_ff @(posedge clk_a or negedge rst_n) begin
            if (!rst_n) a_direct <= 1'b0;
            else a_direct <= 1'b1;
          end
          always_ff @(posedge clk_b or negedge rst_n) begin
            if (!rst_n) begin
              b_sync1 <= 1'b0;
              b_sync2 <= 1'b0;
            end else begin
              b_sync1 <= 1'b1;
              b_sync2 <= b_sync1;
            end
          end
          assign q_a = a_sync2;
          assign q_b = b_sync2;
        endmodule
        """
        let reference = makeReference(path: "rdc-reset-mixed.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(
            makeRequest(reference: reference, analysis: .rdc)
        )

        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "RDC_UNSAFE_RESET_CROSSING" })
        #expect(envelope.payload.coverage.resetReleaseDomains == ["rst_n@clk_b"])
    }

    @Test("RDC blocks a cross-domain reset without synchronizers", .timeLimit(.minutes(1)))
    func rdcBlocksUnsynchronizedResetCrossing() async throws {
        let source = """
        module top(input logic clk_a, input logic clk_b, input logic rst_n, output logic q_a, output logic q_b);
          always_ff @(posedge clk_a or negedge rst_n) begin
            if (!rst_n) q_a <= 1'b0;
            else q_a <= 1'b1;
          end
          always_ff @(posedge clk_b or negedge rst_n) begin
            if (!rst_n) q_b <= 1'b0;
            else q_b <= 1'b1;
          end
        endmodule
        """
        let reference = makeReference(path: "rdc-reset-crossing.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(
            makeRequest(reference: reference, analysis: .rdc)
        )

        #expect(envelope.status == .failed)
        #expect(envelope.payload.coverage.resetReleaseDomains.isEmpty)
        #expect(envelope.payload.findings.contains { $0.code == "RDC_UNSAFE_RESET_CROSSING" })
    }

    @Test("RDC blocks a reset process without a resolvable clock", .timeLimit(.minutes(1)))
    func rdcBlocksUnresolvedClock() async throws {
        let source = """
        module top(input logic rst_n, output logic q);
          always_ff @() begin
            if (!rst_n) q <= 1'b0;
            else q <= 1'b1;
          end
        endmodule
        """
        let reference = makeReference(path: "rdc-unresolved.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(
            makeRequest(reference: reference, analysis: .rdc)
        )

        #expect(envelope.status == .blocked)
        #expect(envelope.rtlDiagnostics.contains { $0.code == "RDC_CLOCK_DOMAIN_UNRESOLVED" })
    }

    @Test("formal mismatch persists a counterexample artifact", .timeLimit(.minutes(1)))
    func formalCounterexampleFixture() async throws {
        let implementation = "module top(input logic a, output logic q); assign q = a; endmodule"
        let referenceSource = "module top(input logic a, output logic q); assign q = ~a; endmodule"
        let implementationReference = makeReference(path: "implementation.sv", format: .systemVerilog, data: Data(implementation.utf8))
        let referenceDesignReference = makeReference(path: "reference.sv", format: .systemVerilog, data: Data(referenceSource.utf8))
        let store = InMemoryRTLArtifactStore()
        let reader = InMemoryRTLArtifactReader(artifacts: [
            implementationReference.path: Data(implementation.utf8),
            referenceDesignReference.path: Data(referenceSource.utf8)
        ])
        let request = makeRequest(
            reference: implementationReference,
            analysis: .formalEquivalence,
            referenceDesign: LogicDesignReference(
                artifact: referenceDesignReference,
                topDesignName: "top",
                designDigest: "reference-digest"
            )
        )
        let envelope = try await NativeFormalEquivalenceChecker(
            reader: reader,
            writer: store
        ).execute(request)
        #expect(envelope.status == .blocked)
        #expect(envelope.payload.proofStatus == "unproven")
        #expect(envelope.payload.counterexampleArtifactIDs == ["formal-counterexample"])
        #expect(envelope.artifacts.contains { $0.artifactID == "formal-counterexample" })
        let counterexampleReference = try #require(envelope.artifacts.first { $0.artifactID == "formal-counterexample" })
        let counterexampleData = try #require(await store.data(for: counterexampleReference))
        let counterexample = try JSONDecoder().decode(RTLFormalCounterexample.self, from: counterexampleData)
        #expect(counterexample.differences.count == 1)
        #expect(counterexample.differences.first?.kind == .moduleStructure)
        #expect(counterexample.differences.first?.entity == "top")
        #expect(counterexample.differences.first?.implementationValue != counterexample.differences.first?.referenceValue)
    }

    @Test("native mapped proof lowers the source snapshot and compares the mapped execution graph", .timeLimit(.minutes(1)))
    func mappedExecutionEquivalenceProvesMatchingSynthesis() async throws {
        let snapshot = try LogicDesignSnapshotCodec.finalized(LogicDesignSnapshot(
            rtl: RTLDesign(
                topModuleName: "top",
                modules: [RTLModule(
                    id: "module-top",
                    name: "top",
                    ports: [
                        RTLPort(id: "a", name: "a", direction: .input),
                        RTLPort(id: "b", name: "b", direction: .input),
                        RTLPort(id: "y", name: "y", direction: .output),
                    ],
                    assignments: [RTLAssignment(
                        id: "assignment-y",
                        target: .identifier("y"),
                        value: .binary(operator: "&", left: .identifier("a"), right: .identifier("b"))
                    )]
                )]
            )
        ))
        let sourceData = try LogicDesignSnapshotCodec.encode(snapshot)
        let sourceReference = makeJSONReference(
            path: "source-snapshot.json",
            kind: .rtl,
            data: sourceData
        )
        let lowering = NativeLogicDesignLowering().lower(snapshot)
        let mappedDocument = try #require(lowering.document)
        let mappedData = try encodeJSON(mappedDocument)
        let mappedReference = makeJSONReference(path: "mapped-design.json", kind: .netlist, data: mappedData)
        let sourceDesign = LogicDesignReference(
            artifact: sourceReference,
            topDesignName: "top",
            designDigest: try #require(snapshot.designDigest)
        )
        let mappedDesign = LogicDesignReference(
            artifact: mappedReference,
            topDesignName: "top",
            designDigest: mappedReference.digest.hexadecimalValue
        )
        let request = RTLVerificationRequest(
            runID: "mapped-proof-pass",
            inputs: [sourceReference, mappedReference],
            design: sourceDesign,
            referenceDesign: mappedDesign,
            analysis: .formalEquivalence,
            proofView: .rtlToMappedExecutionStructural
        )
        let store = InMemoryRTLArtifactStore()
        let reader = InMemoryRTLArtifactReader(artifacts: [
            sourceReference.path: sourceData,
            mappedReference.path: mappedData,
        ])

        let envelope = try await NativeFormalEquivalenceChecker(
            reader: reader,
            writer: store
        ).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.proofStatus == "proved")
        #expect(envelope.payload.findings.contains { $0.code == "FORMAL_MAPPED_EXECUTION_PROVED" })
        #expect(envelope.payload.coverage.proofScope == "rtlToMappedExecutionStructural")
        #expect(envelope.artifacts.contains { $0.artifactID == "rtl-verification-report" })

    }

    @Test("native mapped proof blocks a mapped graph mismatch and retains a counterexample", .timeLimit(.minutes(1)))
    func mappedExecutionEquivalenceBlocksMismatch() async throws {
        let snapshot = try LogicDesignSnapshotCodec.finalized(LogicDesignSnapshot(
            rtl: RTLDesign(
                topModuleName: "top",
                modules: [RTLModule(
                    id: "module-top",
                    name: "top",
                    ports: [
                        RTLPort(id: "a", name: "a", direction: .input),
                        RTLPort(id: "b", name: "b", direction: .input),
                        RTLPort(id: "y", name: "y", direction: .output),
                    ],
                    assignments: [RTLAssignment(
                        id: "assignment-y",
                        target: .identifier("y"),
                        value: .binary(operator: "&", left: .identifier("a"), right: .identifier("b"))
                    )]
                )]
            )
        ))
        let sourceData = try LogicDesignSnapshotCodec.encode(snapshot)
        let sourceReference = makeJSONReference(path: "mismatch-source.json", kind: .rtl, data: sourceData)
        let lowering = NativeLogicDesignLowering().lower(snapshot)
        var mappedDocument = try #require(lowering.document)
        mappedDocument.nodes[0].kind = .or
        let mappedData = try encodeJSON(mappedDocument)
        let mappedReference = makeJSONReference(path: "mismatch-mapped.json", kind: .netlist, data: mappedData)
        let request = RTLVerificationRequest(
            runID: "mapped-proof-mismatch",
            inputs: [sourceReference, mappedReference],
            design: LogicDesignReference(
                artifact: sourceReference,
                topDesignName: "top",
                designDigest: try #require(snapshot.designDigest)
            ),
            referenceDesign: LogicDesignReference(
                artifact: mappedReference,
                topDesignName: "top",
                designDigest: mappedReference.digest.hexadecimalValue
            ),
            analysis: .formalEquivalence,
            proofView: .rtlToMappedExecutionStructural
        )
        let reader = InMemoryRTLArtifactReader(artifacts: [
            sourceReference.path: sourceData,
            mappedReference.path: mappedData,
        ])
        let store = InMemoryRTLArtifactStore()

        let envelope = try await NativeFormalEquivalenceChecker(
            reader: reader,
            writer: store
        ).execute(request)

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.proofStatus == "unproven")
        #expect(envelope.payload.counterexampleArtifactIDs == ["formal-mapped-execution-counterexample"])
        #expect(envelope.rtlDiagnostics.contains { $0.code == "FORMAL_MAPPED_EXECUTION_UNPROVEN" })
    }

    @Test("unassessed observation maturity does not claim execution authority", .timeLimit(.minutes(1)))
    func unassessedObservationDoesNotBlockExecution() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let reference = makeReference(path: "record.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let request = makeRequest(reference: reference, analysis: .lint)

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.record.maturity == .unassessed)
        #expect(envelope.rtlDiagnostics.contains { $0.code == "RTL_QUALIFICATION_INSUFFICIENT" } == false)
    }

    @Test("observation maturity is ordered without release semantics")
    func observationMaturityIsOrdered() {
        #expect(RTLVerificationEvidenceMaturity.unassessed < .smokeObserved)
        #expect(RTLVerificationEvidenceMaturity.smokeObserved < .corpusObserved)
        #expect(RTLVerificationEvidenceMaturity.corpusObserved < .oracleCorrelated)
    }

    @Test("observation evaluator advances only with independent artifact-bound evidence")
    func observationEvaluator() {
        let corpus = RTLVerificationCorpusEvaluation(
            caseID: "lint-positive",
            matched: true,
            observedStatus: .completed,
            observedFindingCodes: [],
            mismatches: []
        )
        let oracle = RTLVerificationOracleCorrelationReport(
            caseID: "lint-positive",
            nativeImplementationID: "native",
            oracleImplementationID: "oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: true
        )
        let oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle:lint-positive",
            caseID: "lint-positive",
            requestDigest: "request-digest",
            nativePayloadRequestDigest: "request-digest",
            oraclePayloadRequestDigest: "request-digest",
            nativeArtifact: makeJSONReference(
                path: "native-lint-positive.json",
                kind: .report,
                data: Data("native".utf8),
                artifactID: "native-lint-positive"
            ),
            oracleArtifact: makeJSONReference(
                path: "oracle-lint-positive.json",
                kind: .report,
                data: Data("oracle".utf8),
                artifactID: "oracle-lint-positive"
            ),
            report: oracle,
            oracleProvenance: "retained-independent-oracle",
            recordedAt: Date(timeIntervalSince1970: 1)
        )
        #expect(oracleEvidence.isAuditable)
        let report = RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [corpus],
            oracleReports: [oracle],
            oracleEvidence: [oracleEvidence],
            expectedRequestDigest: "request-digest",
            checkedAt: Date(timeIntervalSince1970: 1)
        )

        #expect(report.maturity == .oracleCorrelated)
        #expect(report.limitations.isEmpty)
        #expect(report.evidence.map(\.evidenceID) == [
            "corpus:lint-positive",
            "oracle:lint-positive"
        ])
    }

    @Test("observation evaluator does not synthesize process authority")
    func observationEvaluatorDoesNotSynthesizeProcessAuthority() {
        let report = RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [],
            oracleReports: []
        )

        #expect(report.maturity == .unassessed)
        #expect(report.evidence.isEmpty)
    }

    @Test("observation assessment retains the evaluated implementation identity")
    func observationAssessmentRetainsImplementationIdentity() {
        let now = Date(timeIntervalSince1970: 1)
        let report = RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [],
            oracleReports: [],
            checkedAt: now
        )

        #expect(report.implementationID == "native")
        #expect(report.implementationVersion == "1")
        #expect(report.checkedAt == now)
    }

    @Test("oracle correlation requires matching retained evidence")
    func oracleCorrelationRequiresMatchingRetainedEvidence() {
        let now = Date(timeIntervalSince1970: 1)
        let corpus = RTLVerificationCorpusEvaluation(
            caseID: "lint-positive",
            matched: true,
            observedStatus: .completed,
            observedFindingCodes: [],
            mismatches: []
        )
        let oracle = RTLVerificationOracleCorrelationReport(
            caseID: "lint-positive",
            nativeImplementationID: "native",
            oracleImplementationID: "oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: true,
            checkedAt: now
        )
        let oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle-evidence:lint-positive",
            caseID: "lint-positive",
            requestDigest: "request-digest",
            nativePayloadRequestDigest: "request-digest",
            oraclePayloadRequestDigest: "request-digest",
            nativeArtifact: makeJSONReference(
                path: "binding-native.json",
                kind: .report,
                data: Data("native".utf8),
                artifactID: "binding-native"
            ),
            oracleArtifact: makeJSONReference(
                path: "binding-oracle.json",
                kind: .report,
                data: Data("oracle".utf8),
                artifactID: "binding-oracle"
            ),
            report: oracle,
            oracleProvenance: "retained-independent-oracle",
            recordedAt: now
        )
        var mismatchedEvidence = oracleEvidence
        mismatchedEvidence.requestDigest = "different-request-digest"

        let report = RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [corpus],
            oracleReports: [oracle],
            oracleEvidence: [mismatchedEvidence],
            expectedRequestDigest: "request-digest",
            checkedAt: now
        )

        #expect(report.maturity == .corpusObserved)
        #expect(report.evidence.map(\.kind) == [.corpus])
    }

    @Test("record rejects an expired process record")
    func expiredProcessQualificationIsRejected() {
        let scope = RTLVerificationProcessEvidenceScope(
            implementationID: "native",
            binaryDigest: "binary",
            algorithmVersion: "1",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.lint]
        )
        let record = RTLVerificationProcessEvidenceRecord(
            evidenceSetID: "expired-process",
            scope: scope,
            status: .complete,
            corpusEvidenceIDs: ["corpus"],
            oracleEvidenceIDs: ["oracle"],
            healthEvidenceIDs: ["health"],
            recordedAt: Date(timeIntervalSince1970: 1),
            validUntil: Date(timeIntervalSince1970: 2)
        )

        #expect(record.isComplete(at: Date(timeIntervalSince1970: 1.5)))
        #expect(!record.isComplete(at: Date(timeIntervalSince1970: 2)))
        #expect(!record.isFresh(at: Date(timeIntervalSince1970: 3)))
    }

    @Test("process evidence scope remains descriptive rather than authoritative")
    func processEvidenceScopeIsDescriptive() {
        let scope = RTLVerificationProcessEvidenceScope(
            implementationID: "other-implementation",
            binaryDigest: "binary",
            algorithmVersion: "other-version",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.cdc]
        )
        #expect(scope.implementationID == "other-implementation")
        #expect(scope.algorithmVersion == "other-version")
        #expect(scope.analyses == [.cdc])
    }

    @Test("oracle evidence rejects unmatched correlation")
    func oracleEvidenceRejectsUnmatchedCorrelation() throws {
        let report = RTLVerificationOracleCorrelationReport(
            caseID: "oracle-case",
            nativeImplementationID: "native",
            oracleImplementationID: "oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: false
        )
        let evidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle-evidence",
            caseID: "oracle-case",
            requestDigest: "request-digest",
            nativePayloadRequestDigest: "request-digest",
            oraclePayloadRequestDigest: "request-digest",
            nativeArtifact: makeTestArtifactReference(
                path: "native.json",
                kind: .report,
                format: .json
            ),
            oracleArtifact: makeJSONReference(
                path: "oracle.json",
                kind: .report,
                data: Data("oracle".utf8),
                artifactID: "oracle-result"
            ),
            report: report,
            oracleProvenance: "retained-independent-oracle"
        )

        #expect(!evidence.isAuditable)
        #expect(throws: RTLVerificationOracleEvidenceValidationError.notAuditable) {
            try RTLVerificationOracleEvidenceValidator().validate(evidence)
        }
    }

    @Test("oracle record requires the expected request digest")
    func oracleQualificationRequiresRequestDigest() {
        let report = RTLVerificationOracleCorrelationReport(
            caseID: "oracle-case",
            nativeImplementationID: "native",
            oracleImplementationID: "oracle",
            nativeImplementationVersion: "1",
            oracleImplementationVersion: "1",
            independenceVerified: true,
            matched: true
        )
        let evidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle-evidence",
            caseID: "oracle-case",
            requestDigest: "request-digest",
            nativePayloadRequestDigest: "request-digest",
            oraclePayloadRequestDigest: "request-digest",
            nativeArtifact: makeJSONReference(
                path: "native.json",
                kind: .report,
                data: Data("native".utf8),
                artifactID: "native-result"
            ),
            oracleArtifact: makeJSONReference(
                path: "oracle.json",
                kind: .report,
                data: Data("oracle".utf8),
                artifactID: "oracle-result"
            ),
            report: report,
            oracleProvenance: "retained-independent-oracle"
        )

        let record = RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [RTLVerificationCorpusEvaluation(
                caseID: "oracle-case",
                matched: true,
                observedStatus: .completed,
                observedFindingCodes: [],
                mismatches: []
            )],
            oracleReports: [report],
            oracleEvidence: [evidence]
        )

        #expect(record.maturity == .corpusObserved)
        #expect(record.evidence.map(\.kind) == [.corpus])
        #expect(throws: RTLVerificationOracleEvidenceValidationError.requestDigestMismatch(
            expected: "other-request-digest",
            observed: "request-digest"
        )) {
            try RTLVerificationOracleEvidenceValidator().validate(
                evidence,
                expectedRequestDigest: "other-request-digest"
            )
        }
    }

    @Test("observation evaluator represents missing observations as unassessed")
    func observationEvaluatorRepresentsMissingObservations() {
        let report = RTLVerificationEvidenceEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [],
            oracleReports: []
        )

        #expect(report.maturity == .unassessed)
        #expect(report.evidence.isEmpty)
        #expect(report.limitations.isEmpty)
    }

    @Test("frontend preserves source provenance and applies deterministic defines", .timeLimit(.minutes(1)))
    func frontendPreprocessesDefines() async throws {
        let source = """
        `ifdef ENABLE_TOP
        module top(input logic a, output logic q); assign q = a; endmodule
        `else
        module disabled(input logic a, output logic q); assign q = a; endmodule
        `endif
        """
        let reference = makeReference(path: "preprocessed.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let request = makeRequest(
            reference: reference,
            analysis: .lint,
            policy: RTLVerificationPolicy(maximumUnsupportedConstructs: 0),
            frontend: RTLVerificationFrontendOptions(preprocessorDefines: ["ENABLE_TOP": "1"])
        )

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.sourceArtifacts.count == 1)
        #expect(envelope.payload.coverage.sourceArtifacts.first?.path == "preprocessed.sv")
        #expect(envelope.payload.coverage.sourceArtifacts.first?.sha256.isEmpty == false)
    }

    @Test("frontend selects the first matching elsif branch", .timeLimit(.minutes(1)))
    func frontendSupportsElsif() async throws {
        let source = """
        `ifdef FIRST
        module first(input logic a, output logic q); assign q = a; endmodule
        `elsif SECOND
        module second(input logic a, output logic q); assign q = a; endmodule
        `else
        module fallback(input logic a, output logic q); assign q = a; endmodule
        `endif
        """
        let reference = makeReference(path: "elsif.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        var request = makeRequest(reference: reference, analysis: .lint)
        request.design.topDesignName = "second"
        request.frontend = RTLVerificationFrontendOptions(preprocessorDefines: ["SECOND": "1"])

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.unsupportedConstructs.isEmpty)
    }

    @Test("unsupported include directives block the default frontend policy", .timeLimit(.minutes(1)))
    func frontendBlocksUnsupportedInclude() async throws {
        let source = """
        `include \"missing.svh\"
        module top(input logic a, output logic q); assign q = a; endmodule
        """
        let reference = makeReference(path: "include.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let envelope = try await NativeRTLLintEngine(reader: reader).execute(
            makeRequest(reference: reference, analysis: .lint)
        )

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.coverage.unsupportedConstructs == ["include:missing.svh"])
    }

    @Test("frontend resolves source-set includes and shares compile definitions", .timeLimit(.minutes(1)))
    func frontendResolvesIncludes() async throws {
        let headerSource = "`define SOURCE_SIGNAL a"
        let topSource = """
        `include \"defs.svh\"
        module top(input logic a, output logic q); assign q = `SOURCE_SIGNAL; endmodule
        """
        let header = makeReference(path: "defs.svh", format: .systemVerilog, data: Data(headerSource.utf8))
        let top = makeReference(path: "included-top.sv", format: .systemVerilog, data: Data(topSource.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [
            header.path: Data(headerSource.utf8),
            top.path: Data(topSource.utf8)
        ])
        var request = makeRequest(reference: top, analysis: .lint)
        request.inputs.append(header)

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.unsupportedConstructs.isEmpty)
        #expect(envelope.payload.coverage.sourceArtifacts.map(\.path) == ["included-top.sv", "defs.svh"])
    }

    @Test("included RTL declarations retain their original source path")
    func includedSourceLocationProvenance() throws {
        let topData = Data("`include \"child-module.svh\"\nmodule top; endmodule".utf8)
        let headerData = Data("module child(input logic a, output logic q); assign q = a; endmodule".utf8)
        let headerReference = makeReference(path: "child-module.svh", format: .systemVerilog, data: headerData)
        let topReference = makeReference(path: "include-location.sv", format: .systemVerilog, data: topData)
        let parsed = try SystemVerilogRTLParser().parse(
            sources: [
                RTLVerificationSourceInput(
                    reference: topReference,
                    data: topData
                ),
                RTLVerificationSourceInput(
                    reference: headerReference,
                    data: headerData
                )
            ],
            topModuleName: "top",
            options: RTLVerificationFrontendOptions()
        )

        let child = try #require(parsed.design.modules.first { $0.name == "child" })
        #expect(child.ports.first?.source?.start.path == "child-module.svh")
    }

    @Test("CDC projects SDC clock declarations into auditable coverage", .timeLimit(.minutes(1)))
    func cdcProjectsConstraints() async throws {
        let source = """
        module top(input logic clk, output logic q);
          always_ff @(posedge clk) q <= 1'b0;
        endmodule
        """
        let constraintData = Data("""
            create_clock -name other -period 10 [get_ports other]
            set_false_path -from [get_clocks clk] -to [get_clocks other]
            set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks other]
            """.utf8)
        let rtl = makeReference(path: "constrained.sv", format: .systemVerilog, data: Data(source.utf8))
        let sdc = makeTestArtifactReference(path: "constraints.sdc", kind: .constraint, format: .sdc, data: constraintData)
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: Data(source.utf8),
            sdc.path: constraintData
        ])
        var request = makeRequest(
            reference: rtl,
            analysis: .cdc,
            constraints: RTLConstraintReference(artifact: sdc, modeIDs: ["functional"])
        )
        request.inputs.append(sdc)

        let envelope = try await NativeCDCAnalyzer(reader: reader).execute(request)

        #expect(envelope.status == .failed)
        #expect(envelope.payload.coverage.constraintModes == ["functional"])
        #expect(envelope.payload.coverage.constrainedClockDomains == ["other"])
        #expect(envelope.payload.coverage.constraintExceptionKinds == ["falsePath"])
        #expect(envelope.payload.coverage.asynchronousClockGroups == [[ ["clk"], ["other"] ]])
        #expect(envelope.payload.coverage.limitations.contains {
            $0.contains("does not treat them as safety waivers")
        })
        #expect(envelope.payload.findings.contains { $0.code == "CDC_CLOCK_UNCONSTRAINED" })
        #expect(envelope.payload.coverage.sourceArtifacts.contains { $0.path == "constraints.sdc" })
    }

    @Test("native formal blocks proof views outside its declared scope", .timeLimit(.minutes(1)))
    func nativeFormalProofViewBoundary() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let implementation = makeReference(path: "implementation-view.sv", format: .systemVerilog, data: Data(source.utf8))
        let reference = makeReference(path: "reference-view.sv", format: .systemVerilog, data: Data(source.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [
            implementation.path: Data(source.utf8),
            reference.path: Data(source.utf8)
        ])
        let request = makeRequest(
            reference: implementation,
            analysis: .formalEquivalence,
            referenceDesign: LogicDesignReference(
                artifact: reference,
                topDesignName: "top",
                designDigest: "reference-digest"
            ),
            proofView: .rtlToSynthesized
        )

        let envelope = try await NativeFormalEquivalenceChecker(reader: reader).execute(request)

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.proofView == .rtlToSynthesized)
        #expect(envelope.rtlDiagnostics.contains { $0.code == "RTL_REQUEST_INVALID" })
    }

    @Test("retained corpus evaluator records deterministic mismatches", .timeLimit(.minutes(1)))
    func corpusEvaluator() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let reference = makeReference(path: "corpus.sv", format: .systemVerilog, data: Data(source.utf8))
        let request = makeRequest(reference: reference, analysis: .lint)
        let corpusCase = RTLVerificationCorpusCase(
            caseID: "lint-positive",
            request: request,
            expectation: RTLVerificationCorpusExpectation(
                status: .completed,
                forbiddenFindingCodes: ["RTL_WIDTH_MISMATCH"],
                minimumAnalyzedFraction: 0.1
            )
        )
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let result = try await NativeRTLLintEngine(reader: reader).execute(request)

        let evaluation = RTLVerificationCorpusEvaluator().evaluate(corpusCase, result: result)

        #expect(evaluation.matched)
        #expect(evaluation.mismatches.isEmpty)
    }

    @Test("oracle correlation requires an independent implementation", .timeLimit(.minutes(1)))
    func oracleCorrelationRequiresIndependence() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let reference = makeReference(path: "oracle.sv", format: .systemVerilog, data: Data(source.utf8))
        let request = makeRequest(reference: reference, analysis: .lint)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let native = try await NativeRTLLintEngine(reader: reader).execute(request)
        let oracle = try replacingRTLTestProducer(
            in: native,
            implementationID: "reference-oracle",
            implementationVersion: "oracle-1"
        )

        let report = RTLVerificationOracleCorrelator().correlate(
            caseID: "lint-positive",
            native: native,
            oracle: oracle
        )

        #expect(report.matched)
        #expect(report.independenceVerified)
        #expect(report.evidenceRecord(
            evidenceID: "oracle-correlation-1",
            artifactIDs: ["native-result", "oracle-result"],
            scopeID: "lint-positive"
        ) != nil)

        let selfOracle = try replacingRTLTestProducer(
            in: native,
            implementationID: native.provenance.producer.build
                ?? native.provenance.producer.identifier,
            implementationVersion: "self-oracle"
        )
        let selfReport = RTLVerificationOracleCorrelator().correlate(
            caseID: "lint-self",
            native: native,
            oracle: selfOracle
        )
        #expect(!selfReport.matched)
        #expect(selfReport.mismatches.contains { $0.kind == .oracleNotIndependent })
    }

    @Test("tool record operation IDs include the formal proof view")
    func qualificationOperationID() {
        let reference = makeReference(
            path: "record-operation.sv",
            format: .systemVerilog,
            data: Data("module top; endmodule".utf8)
        )
        let request = makeRequest(
            reference: reference,
            analysis: .formalEquivalence,
            proofView: .synthesizedToDFT
        )

        #expect(
            RTLVerificationToolTrustPolicy().operationID(for: request)
                == "rtl.equivalence.synthesizedToDFT"
        )
    }

    @Test("multi-file RTL inputs retain ordered provenance", .timeLimit(.minutes(1)))
    func multiFileProvenance() async throws {
        let childSource = "module child(input logic a, output logic y); assign y = a; endmodule"
        let topSource = "module top(input logic a, output logic q); child u(.a(a), .y(q)); endmodule"
        let top = makeReference(path: "top-multi.sv", format: .systemVerilog, data: Data(topSource.utf8))
        let child = makeReference(path: "child-multi.sv", format: .systemVerilog, data: Data(childSource.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [
            top.path: Data(topSource.utf8),
            child.path: Data(childSource.utf8)
        ])
        var request = makeRequest(reference: top, analysis: .lint)
        request.inputs.append(child)

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.coverage.sourceArtifacts.map(\.path) == ["top-multi.sv", "child-multi.sv"])
    }

    @Test("formal reference inputs use the same source-set frontend", .timeLimit(.minutes(1)))
    func formalReferenceSourceSet() async throws {
        let topSource = "module top(input logic a, output logic q); child u(.a(a), .y(q)); endmodule"
        let childSource = "module child(input logic a, output logic y); assign y = a; endmodule"
        let referenceTopSource = "`include \"formal-reference-child.svh\"\nmodule top(input logic a, output logic q); child u(.a(a), .y(q)); endmodule"
        let implementationTop = makeReference(path: "formal-implementation.sv", format: .systemVerilog, data: Data(topSource.utf8))
        let implementationChild = makeReference(path: "formal-implementation-child.sv", format: .systemVerilog, data: Data(childSource.utf8))
        let referenceTop = makeReference(path: "formal-reference.sv", format: .systemVerilog, data: Data(referenceTopSource.utf8))
        let referenceChild = makeReference(path: "formal-reference-child.svh", format: .systemVerilog, data: Data(childSource.utf8))
        let reader = InMemoryRTLArtifactReader(artifacts: [
            implementationTop.path: Data(topSource.utf8),
            implementationChild.path: Data(childSource.utf8),
            referenceTop.path: Data(referenceTopSource.utf8),
            referenceChild.path: Data(childSource.utf8)
        ])
        let store = InMemoryRTLArtifactStore()
        let request = RTLVerificationRequest(
            runID: "formal-reference-source-set",
            inputs: [implementationTop, implementationChild],
            design: LogicDesignReference(
                artifact: implementationTop,
                topDesignName: "top",
                designDigest: "implementation-digest"
            ),
            referenceDesign: LogicDesignReference(
                artifact: referenceTop,
                topDesignName: "top",
                designDigest: "reference-digest"
            ),
            referenceInputs: [referenceTop, referenceChild],
            analysis: .formalEquivalence
        )

        let envelope = try await NativeFormalEquivalenceChecker(
            reader: reader,
            writer: store
        ).execute(request)

        #expect(envelope.status == .completed)
        #expect(envelope.payload.proofStatus == "proved")
        #expect(envelope.payload.coverage.sourceArtifacts.map(\.path) == [
            "formal-implementation.sv",
            "formal-implementation-child.sv",
            "formal-reference.sv",
            "formal-reference-child.svh"
        ])
        let reportReference = try #require(envelope.artifacts.first { $0.artifactID == "rtl-verification-report" })
        let reportData = try #require(await store.data(for: reportReference))
        let report = try JSONDecoder().decode(RTLVerificationReport.self, from: reportData)
        #expect(report.inputArtifacts.map(\.path) == [
            "formal-implementation.sv",
            "formal-implementation-child.sv",
            "formal-reference.sv",
            "formal-reference-child.svh"
        ])
    }

    private func makeReference(path: String, format: ArtifactFormat, data: Data) -> ArtifactReference {
        makeTestArtifactReference(path: path, kind: .rtl, format: format, data: data)
    }

    private func encodeJSON<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func makeJSONReference(
        path: String,
        kind: ArtifactKind,
        data: Data,
        artifactID: String? = nil
    ) -> ArtifactReference {
        makeTestArtifactReference(
            artifactID: artifactID,
            path: path,
            kind: kind,
            format: .json,
            sha256: SHA256ContentDigester().sha256(data: data),
            byteCount: Int64(data.count)
        )
    }

    private func makeRequest(
        reference: ArtifactReference,
        analysis: RTLVerificationAnalysis,
        referenceDesign: LogicDesignReference? = nil,
        constraints: RTLConstraintReference? = nil,
        waivers: [RTLVerificationWaiver] = [],
        policy: RTLVerificationPolicy = RTLVerificationPolicy(),
        frontend: RTLVerificationFrontendOptions = RTLVerificationFrontendOptions(),
        proofView: RTLVerificationProofView = .rtlToRtlStructural,
        assumptions: [RTLVerificationAssumption] = []
    ) -> RTLVerificationRequest {
        RTLVerificationRequest(
            runID: "test-run",
            inputs: [reference],
            design: LogicDesignReference(
                artifact: reference,
                topDesignName: "top",
                designDigest: "design-digest"
            ),
            referenceDesign: referenceDesign,
            constraints: constraints,
            analysis: analysis,
            policy: policy,
            waivers: waivers,
            frontend: frontend,
            proofView: proofView,
            assumptions: assumptions
        )
    }
}
