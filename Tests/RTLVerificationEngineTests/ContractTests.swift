import Foundation
import LogicEngineCore
import LogicLowering
import LogicIR
import TimingCore
import Testing
import XcircuitePackage
@testable import RTLVerificationCore
@testable import RTLLint
@testable import CDCAnalysis
@testable import RDCAnalysis
@testable import FormalEquivalence
@testable import RTLVerificationEngine

@Suite("RTLVerificationEngine contract")
struct ContractTests {
    @Test("contract version starts at one")
    func contractVersion() {
        #expect(RTLVerificationEngineAPI.contractVersion == 1)
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
        let reference = XcircuiteFileReference(
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
                reason: "Reviewed by design owner.",
                approvedBy: "verification"
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
            coverage: RTLVerificationCoverage(clockDomains: ["clk"]),
            appliedWaivers: request.waivers,
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
        let reference = makeReference(path: "top.sv", format: .systemVerilog)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let engine = NativeRTLLintEngine(reader: reader)
        let envelope = try await engine.execute(makeRequest(reference: reference, analysis: .lint))
        #expect(envelope.status == .completed)
        #expect(envelope.payload.findings.isEmpty)
        #expect(envelope.payload.coverage.analyzedConstructs > 0)
        #expect(envelope.artifacts.count == 1)
    }

    @Test("native lint retains negative findings and applies scoped waivers", .timeLimit(.minutes(1)))
    func nativeLintNegativeFixture() async throws {
        let source = """
        module top(input logic a, input logic b, output logic [7:0] q);
          logic x;
          assign x = a;
          assign x = b;
          assign q = a;
        endmodule
        """
        let reference = makeReference(path: "negative.sv", format: .systemVerilog)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let waiver = RTLVerificationWaiver(
            waiverID: "waiver-width",
            code: "RTL_WIDTH_MISMATCH",
            entity: "top.q",
            reason: "Intentional extension documented in the design review.",
            approvedBy: "verification"
        )
        let request = makeRequest(reference: reference, analysis: .lint, waivers: [waiver])
        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)
        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "RTL_MULTIPLE_DRIVER" })
        #expect(envelope.payload.findings.contains { $0.code == "RTL_WIDTH_MISMATCH" && $0.waived })
        #expect(envelope.payload.appliedWaivers == [waiver])
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
        let reference = makeReference(path: "cdc-negative.sv", format: .systemVerilog)
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
        let reference = makeReference(path: "cdc-order.sv", format: .systemVerilog)
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
        let reference = makeReference(path: "rdc.sv", format: .systemVerilog)
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
        let rtl = makeReference(path: "rdc-constrained.sv", format: .systemVerilog)
        let sdc = XcircuiteFileReference(path: "rdc.sdc", kind: .constraint, format: .sdc)
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: Data(source.utf8),
            sdc.path: Data("create_clock -name clk -period 10 [get_ports clk]".utf8)
        ])
        var request = makeRequest(
            reference: rtl,
            analysis: .rdc,
            constraints: TimingConstraintReference(artifact: sdc, modeIDs: ["reset-signoff"])
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
        let rtl = makeReference(path: "rdc-unconstrained.sv", format: .systemVerilog)
        let sdc = XcircuiteFileReference(path: "rdc-unconstrained.sdc", kind: .constraint, format: .sdc)
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: Data(source.utf8),
            sdc.path: Data("create_clock -name clk -period 10 [get_ports clk]".utf8)
        ])
        var request = makeRequest(
            reference: rtl,
            analysis: .rdc,
            constraints: TimingConstraintReference(artifact: sdc, modeIDs: ["reset-signoff"])
        )
        request.inputs.append(sdc)

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(request)

        #expect(envelope.status == .failed)
        #expect(envelope.payload.findings.contains { $0.code == "RDC_CLOCK_UNCONSTRAINED" })
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
        let reference = makeReference(path: "rdc-unresolved.sv", format: .systemVerilog)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])

        let envelope = try await NativeRDCAnalyzer(reader: reader).execute(
            makeRequest(reference: reference, analysis: .rdc)
        )

        #expect(envelope.status == .blocked)
        #expect(envelope.diagnostics.contains { $0.code == "RDC_CLOCK_DOMAIN_UNRESOLVED" })
    }

    @Test("formal mismatch persists a counterexample artifact", .timeLimit(.minutes(1)))
    func formalCounterexampleFixture() async throws {
        let implementation = "module top(input logic a, output logic q); assign q = a; endmodule"
        let referenceSource = "module top(input logic a, output logic q); assign q = ~a; endmodule"
        let implementationReference = makeReference(path: "implementation.sv", format: .systemVerilog)
        let referenceDesignReference = makeReference(path: "reference.sv", format: .systemVerilog)
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
            designDigest: try #require(mappedReference.sha256)
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
                designDigest: try #require(mappedReference.sha256)
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
        #expect(envelope.diagnostics.contains { $0.code == "FORMAL_MAPPED_EXECUTION_UNPROVEN" })
    }

    @Test("minimum qualification blocks an otherwise executable native result", .timeLimit(.minutes(1)))
    func qualificationGateBlocksNativeExecution() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let reference = makeReference(path: "qualification.sv", format: .systemVerilog)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let request = makeRequest(
            reference: reference,
            analysis: .lint,
            policy: RTLVerificationPolicy(minimumQualification: .processQualified)
        )

        let envelope = try await NativeRTLLintEngine(reader: reader).execute(request)

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.qualification.state == .unassessed)
        #expect(envelope.diagnostics.contains { $0.code == "RTL_QUALIFICATION_INSUFFICIENT" })
    }

    @Test("release eligibility requires an empty blocker set")
    func releaseEligibilityRequiresEvidence() {
        let report = RTLVerificationQualificationReport(
            state: .releaseEligible,
            blockers: ["missing_approval"],
            limitations: []
        )

        #expect(!report.isReleaseEligible)
        #expect(!report.satisfies(.releaseEligible))

        let processReport = RTLVerificationQualificationReport(
            state: .processQualified,
            blockers: ["missing_freshness"],
            limitations: []
        )
        #expect(!processReport.satisfies(.processQualified))

        let scope = RTLVerificationProcessQualificationScope(
            implementationID: "native-rtl-verification",
            binaryDigest: "binary-digest",
            algorithmVersion: "1.0.0",
            processProfileID: "process-1",
            pdkID: "pdk-1",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.lint]
        )
        let qualifiedRecord = RTLVerificationProcessQualificationRecord(
            qualificationID: "qualification-1",
            scope: scope,
            status: .qualified,
            corpusEvidenceIDs: ["corpus-1"],
            oracleEvidenceIDs: ["oracle-1"],
            healthEvidenceIDs: ["health-1"],
            blockers: [],
            qualifiedAt: Date(timeIntervalSince1970: 1),
            expiresAt: Date(timeIntervalSince1970: 2)
        )
        let releaseReport = RTLVerificationQualificationReport(
            state: .releaseEligible,
            blockers: [],
            limitations: [],
            processQualification: qualifiedRecord,
            checkedAt: Date(timeIntervalSince1970: 1)
        )
        #expect(releaseReport.isReleaseEligible)
        #expect(releaseReport.satisfies(.releaseEligible))
    }

    @Test("qualification evaluator advances only with independent evidence")
    func qualificationEvaluator() {
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
        let scope = RTLVerificationProcessQualificationScope(
            implementationID: "native",
            binaryDigest: "binary",
            algorithmVersion: "1",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.lint]
        )
        let process = RTLVerificationProcessQualificationRecord(
            qualificationID: "process-1",
            scope: scope,
            status: .qualified,
            corpusEvidenceIDs: ["corpus:lint-positive"],
            oracleEvidenceIDs: ["oracle:lint-positive"],
            healthEvidenceIDs: ["health:lint"],
            blockers: [],
            qualifiedAt: Date(timeIntervalSince1970: 1),
            expiresAt: Date(timeIntervalSince1970: 2)
        )
        let approval = RTLVerificationQualificationEvidence(
            evidenceID: "approval-1",
            kind: .releaseApproval,
            summary: "Approved by verification owner.",
            checkedAt: Date(timeIntervalSince1970: 1)
        )
        let oracleEvidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle:lint-positive",
            caseID: "lint-positive",
            requestDigest: "request-digest",
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
        let healthEvidence = RTLVerificationQualificationEvidence(
            evidenceID: "health:lint",
            kind: .healthCheck,
            summary: "Native lint health check passed.",
            checkedAt: Date(timeIntervalSince1970: 1)
        )

        let report = RTLVerificationQualificationEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            healthEvidence: [healthEvidence],
            corpusEvaluations: [corpus],
            oracleReports: [oracle],
            oracleEvidence: [oracleEvidence],
            processQualification: process,
            releaseApproval: approval,
            expectedRequestDigest: "request-digest",
            checkedAt: Date(timeIntervalSince1970: 1)
        )

        #expect(report.state == .releaseEligible)
        #expect(report.isReleaseEligible)
        #expect(report.blockers.isEmpty)
        #expect(report.evidence.map(\.evidenceID) == [
            "approval-1",
            "corpus:lint-positive",
            "health:lint",
            "oracle:lint-positive",
            "process:process-1"
        ])
    }

    @Test("qualification binds process evidence IDs to retained evidence")
    func qualificationRequiresProcessEvidenceBinding() {
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
        let scope = RTLVerificationProcessQualificationScope(
            implementationID: "native",
            binaryDigest: "binary",
            algorithmVersion: "1",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.lint]
        )
        let process = RTLVerificationProcessQualificationRecord(
            qualificationID: "process-binding",
            scope: scope,
            status: .qualified,
            corpusEvidenceIDs: ["corpus:other"],
            oracleEvidenceIDs: ["oracle:other"],
            healthEvidenceIDs: ["health:lint"],
            qualifiedAt: now,
            expiresAt: now.addingTimeInterval(60)
        )

        let report = RTLVerificationQualificationEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [corpus],
            oracleReports: [oracle],
            oracleEvidence: [oracleEvidence],
            processQualification: process,
            expectedRequestDigest: "request-digest",
            analysis: .lint,
            checkedAt: now
        )

        #expect(report.state == .oracleCorrelated)
        #expect(report.blockers.contains("process:corpus_evidence_binding_missing:corpus:lint-positive"))
        #expect(report.blockers.contains("process:oracle_evidence_binding_missing:oracle:lint-positive"))
        #expect(report.blockers.contains("process:health_evidence_artifact_missing:health:lint"))
        #expect(!report.isReleaseEligible)
    }

    @Test("qualification rejects an expired process record")
    func expiredProcessQualificationIsRejected() {
        let scope = RTLVerificationProcessQualificationScope(
            implementationID: "native",
            binaryDigest: "binary",
            algorithmVersion: "1",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.lint]
        )
        let record = RTLVerificationProcessQualificationRecord(
            qualificationID: "expired-process",
            scope: scope,
            status: .qualified,
            corpusEvidenceIDs: ["corpus"],
            oracleEvidenceIDs: ["oracle"],
            healthEvidenceIDs: ["health"],
            qualifiedAt: Date(timeIntervalSince1970: 1),
            expiresAt: Date(timeIntervalSince1970: 2)
        )

        #expect(record.isQualified(at: Date(timeIntervalSince1970: 1.5)))
        #expect(!record.isQualified(at: Date(timeIntervalSince1970: 2)))
        #expect(!record.isFresh(at: Date(timeIntervalSince1970: 3)))
    }

    @Test("qualification rejects a process record scoped to another implementation")
    func processQualificationScopeMustMatchRequest() {
        let now = Date()
        let scope = RTLVerificationProcessQualificationScope(
            implementationID: "other-implementation",
            binaryDigest: "binary",
            algorithmVersion: "other-version",
            processProfileID: "profile",
            pdkID: "pdk",
            pdkDigest: "pdk-digest",
            deckDigest: "deck-digest",
            analyses: [.cdc]
        )
        let process = RTLVerificationProcessQualificationRecord(
            qualificationID: "mismatched-process",
            scope: scope,
            status: .qualified,
            corpusEvidenceIDs: ["corpus:lint"],
            oracleEvidenceIDs: ["oracle:lint"],
            healthEvidenceIDs: ["health:lint"],
            qualifiedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60)
        )

        let report = RTLVerificationQualificationEvaluator().evaluate(
            implementationID: "native-rtl-verification",
            implementationVersion: "1.0.0",
            corpusEvaluations: [],
            oracleReports: [],
            processQualification: process,
            analysis: .lint,
            proofView: .rtlToRtlStructural,
            checkedAt: now
        )

        #expect(report.blockers.contains("process:scope_implementation_mismatch"))
        #expect(report.blockers.contains("process:scope_algorithm_version_mismatch"))
        #expect(report.blockers.contains("process:scope_analysis_mismatch"))
        #expect(!report.evidence.contains { $0.kind == .processQualification })
    }

    @Test("oracle evidence requires digest-bound artifacts")
    func oracleEvidenceRequiresDigestBoundArtifacts() throws {
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
            nativeArtifact: XcircuiteFileReference(
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

    @Test("oracle qualification requires the expected request digest")
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

        let qualification = RTLVerificationQualificationEvaluator().evaluate(
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
            oracleEvidence: [evidence],
            processQualification: nil
        )

        #expect(qualification.blockers.contains("oracle_request_digest_required"))
        #expect(!qualification.blockers.isEmpty)
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

    @Test("qualification evaluator retains missing evidence as blockers")
    func qualificationEvaluatorRetainsBlockers() {
        let report = RTLVerificationQualificationEvaluator().evaluate(
            implementationID: "native",
            implementationVersion: "1",
            corpusEvaluations: [],
            oracleReports: [],
            processQualification: nil
        )

        #expect(report.state == .unassessed)
        #expect(report.blockers == [
            "independent_corpus_validation_required",
            "oracle_correlation_required",
            "process_qualification_required"
        ])
        #expect(!report.isReleaseEligible)
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
        let reference = makeReference(path: "preprocessed.sv", format: .systemVerilog)
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
        let reference = makeReference(path: "elsif.sv", format: .systemVerilog)
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
        let reference = makeReference(path: "include.sv", format: .systemVerilog)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let envelope = try await NativeRTLLintEngine(reader: reader).execute(
            makeRequest(reference: reference, analysis: .lint)
        )

        #expect(envelope.status == .blocked)
        #expect(envelope.payload.coverage.unsupportedConstructs == ["include:missing.svh"])
    }

    @Test("frontend resolves source-set includes and shares compile definitions", .timeLimit(.minutes(1)))
    func frontendResolvesIncludes() async throws {
        let header = makeReference(path: "defs.svh", format: .systemVerilog)
        let top = makeReference(path: "included-top.sv", format: .systemVerilog)
        let headerSource = "`define SOURCE_SIGNAL a"
        let topSource = """
        `include \"defs.svh\"
        module top(input logic a, output logic q); assign q = `SOURCE_SIGNAL; endmodule
        """
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
        let headerReference = makeReference(path: "child-module.svh", format: .systemVerilog)
        let topReference = makeReference(path: "include-location.sv", format: .systemVerilog)
        let parsed = try SystemVerilogRTLParser().parse(
            sources: [
                RTLVerificationSourceInput(
                    reference: topReference,
                    data: Data("`include \"child-module.svh\"\nmodule top; endmodule".utf8)
                ),
                RTLVerificationSourceInput(
                    reference: headerReference,
                    data: Data("module child(input logic a, output logic q); assign q = a; endmodule".utf8)
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
        let rtl = makeReference(path: "constrained.sv", format: .systemVerilog)
        let sdc = XcircuiteFileReference(path: "constraints.sdc", kind: .constraint, format: .sdc)
        let reader = InMemoryRTLArtifactReader(artifacts: [
            rtl.path: Data(source.utf8),
            sdc.path: Data("""
            create_clock -name other -period 10 [get_ports other]
            set_false_path -from [get_clocks clk] -to [get_clocks other]
            set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks other]
            """.utf8)
        ])
        var request = makeRequest(
            reference: rtl,
            analysis: .cdc,
            constraints: TimingConstraintReference(artifact: sdc, modeIDs: ["functional"])
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
        let implementation = makeReference(path: "implementation-view.sv", format: .systemVerilog)
        let reference = makeReference(path: "reference-view.sv", format: .systemVerilog)
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
        #expect(envelope.diagnostics.contains { $0.code == "RTL_REQUEST_INVALID" })
    }

    @Test("retained corpus evaluator records deterministic mismatches", .timeLimit(.minutes(1)))
    func corpusEvaluator() async throws {
        let source = "module top(input logic a, output logic q); assign q = a; endmodule"
        let reference = makeReference(path: "corpus.sv", format: .systemVerilog)
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
        let reference = makeReference(path: "oracle.sv", format: .systemVerilog)
        let request = makeRequest(reference: reference, analysis: .lint)
        let reader = InMemoryRTLArtifactReader(artifacts: [reference.path: Data(source.utf8)])
        let native = try await NativeRTLLintEngine(reader: reader).execute(request)
        var oracle = native
        oracle.metadata.implementationID = "reference-oracle"
        oracle.metadata.implementationVersion = "oracle-1"

        let report = RTLVerificationOracleCorrelator().correlate(
            caseID: "lint-positive",
            native: native,
            oracle: oracle
        )

        #expect(report.matched)
        #expect(report.independenceVerified)
        #expect(report.qualificationEvidence(
            evidenceID: "oracle-correlation-1",
            artifactIDs: ["native-result", "oracle-result"]
        ) != nil)

        var selfOracle = native
        selfOracle.metadata.implementationVersion = "self-oracle"
        let selfReport = RTLVerificationOracleCorrelator().correlate(
            caseID: "lint-self",
            native: native,
            oracle: selfOracle
        )
        #expect(!selfReport.matched)
        #expect(selfReport.mismatches.contains { $0.kind == .oracleNotIndependent })
    }

    @Test("tool qualification operation IDs include the formal proof view")
    func qualificationOperationID() {
        let reference = makeReference(path: "qualification-operation.sv", format: .systemVerilog)
        let request = makeRequest(
            reference: reference,
            analysis: .formalEquivalence,
            proofView: .synthesizedToDFT
        )

        #expect(
            RTLVerificationToolQualificationAdapter().operationID(for: request)
                == "rtl.equivalence.synthesizedToDFT"
        )
    }

    @Test("multi-file RTL inputs retain ordered provenance", .timeLimit(.minutes(1)))
    func multiFileProvenance() async throws {
        let childSource = "module child(input logic a, output logic y); assign y = a; endmodule"
        let topSource = "module top(input logic a, output logic q); child u(.a(a), .y(q)); endmodule"
        let top = makeReference(path: "top-multi.sv", format: .systemVerilog)
        let child = makeReference(path: "child-multi.sv", format: .systemVerilog)
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
        let implementationTop = makeReference(path: "formal-implementation.sv", format: .systemVerilog)
        let implementationChild = makeReference(path: "formal-implementation-child.sv", format: .systemVerilog)
        let referenceTop = makeReference(path: "formal-reference.sv", format: .systemVerilog)
        let referenceChild = makeReference(path: "formal-reference-child.svh", format: .systemVerilog)
        let topSource = "module top(input logic a, output logic q); child u(.a(a), .y(q)); endmodule"
        let childSource = "module child(input logic a, output logic y); assign y = a; endmodule"
        let referenceTopSource = "`include \"formal-reference-child.svh\"\nmodule top(input logic a, output logic q); child u(.a(a), .y(q)); endmodule"
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
            referenceInputs: [referenceChild],
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

    private func makeReference(path: String, format: XcircuiteFileFormat) -> XcircuiteFileReference {
        XcircuiteFileReference(path: path, kind: .rtl, format: format)
    }

    private func encodeJSON<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func makeJSONReference(
        path: String,
        kind: XcircuiteFileKind,
        data: Data,
        artifactID: String? = nil
    ) -> XcircuiteFileReference {
        XcircuiteFileReference(
            artifactID: artifactID,
            path: path,
            kind: kind,
            format: .json,
            sha256: XcircuiteHasher().sha256(data: data),
            byteCount: Int64(data.count)
        )
    }

    private func makeRequest(
        reference: XcircuiteFileReference,
        analysis: RTLVerificationAnalysis,
        referenceDesign: LogicDesignReference? = nil,
        constraints: TimingConstraintReference? = nil,
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
