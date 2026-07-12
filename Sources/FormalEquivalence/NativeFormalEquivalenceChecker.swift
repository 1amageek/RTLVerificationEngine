import Foundation
import LogicIR
import RTLVerificationCore
import XcircuitePackage

public struct NativeFormalEquivalenceChecker: FormalEquivalenceChecking {
    public var environment: RTLVerificationEnvironment

    public init(environment: RTLVerificationEnvironment) {
        self.environment = environment
    }

    public init(
        reader: any RTLArtifactReading,
        writer: any RTLArtifactWriting = InMemoryRTLArtifactStore(),
        parser: any RTLVerificationDesignParsing = SystemVerilogRTLParser()
    ) {
        self.environment = RTLVerificationEnvironment(reader: reader, writer: writer, parser: parser)
    }

    public func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
        let startedAt = Date()
        if request.proofView == .rtlToMappedExecutionStructural {
            return try await NativeMappedExecutionEquivalenceChecker(environment: environment).execute(request)
        }
        guard request.analysis == .formalEquivalence else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("Formal equivalence requires analysis=formalEquivalence.")
            )
        }
        guard request.referenceDesign != nil else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("Formal equivalence requires a reference design artifact.")
            )
        }
        guard request.proofView == .rtlToRtlStructural else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest(
                    "Native formal supports only rtlToRtlStructural; the requested proof view requires a qualified solver adapter."
                )
            )
        }
        guard request.assumptions.isEmpty else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest(
                    "Native structural formal does not interpret declared assumptions."
                )
            )
        }

        do {
            let loader = RTLVerificationDesignLoader(reader: environment.reader, parser: environment.parser)
            let implementation = try loader.load(request)
            let reference = try loader.loadReference(request)
            let comparison = RTLStructuralEquivalenceComparator().compare(implementation.design, reference.design)
            let unsupported = implementation.unsupportedConstructs + reference.unsupportedConstructs
            let coverage = RTLVerificationCoverage(
                totalConstructs: implementation.constructCount + reference.constructCount,
                analyzedConstructs: implementation.analyzedConstructCount + reference.analyzedConstructCount,
                unsupportedConstructs: unsupported,
                clockDomains: [],
                resetDomains: [],
                proofScope: request.proofView.rawValue,
                limitations: [
                    "The native proof scope is exact canonical structural equivalence.",
                    "Solver-backed sequential equivalence under temporal assumptions is not provided."
                ] + unsupported.map { "Unsupported construct: \($0)" },
                sourceArtifacts: implementation.sourceArtifacts + reference.sourceArtifacts
            )
            let status: XcircuiteEngineExecutionStatus = unsupported.isEmpty && comparison.mismatches.isEmpty ? .completed : .blocked
            let findings: [RTLVerificationFinding]
            if !unsupported.isEmpty {
                findings = [RTLVerificationFinding(
                    severity: .error,
                    code: "FORMAL_UNSUPPORTED_SEMANTICS",
                    message: "The equivalence proof scope contains unsupported RTL semantics.",
                    entity: request.design.topDesignName,
                    suggestedActions: ["use_supported_subset", "select_qualified_external_solver"]
                )]
            } else if comparison.mismatches.isEmpty {
                findings = [RTLVerificationFinding(
                    severity: .info,
                    code: "FORMAL_EQUIVALENCE_PROVED",
                    message: "The implementation and reference designs are canonically structurally equivalent.",
                    entity: request.design.topDesignName,
                    suggestedActions: ["retain_proof_artifact"]
                )]
            } else {
                findings = [RTLVerificationFinding(
                    severity: .error,
                    code: "FORMAL_EQUIVALENCE_UNPROVEN",
                    message: "The implementation and reference designs differ in the declared proof scope.",
                    entity: request.design.topDesignName,
                    suggestedActions: ["inspect_counterexample", "repair_rtl", "run_qualified_solver"]
                )]
            }
            let counterexampleData: Data?
            let counterexampleID: String?
            if !comparison.mismatches.isEmpty {
                let counterexample = RTLFormalCounterexample(
                    runID: request.runID,
                    topModuleName: request.design.topDesignName,
                    mismatches: comparison.mismatches,
                    affectedEntities: comparison.affectedEntities
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
                counterexampleData = try encoder.encode(counterexample)
                counterexampleID = "formal-counterexample"
            } else {
                counterexampleData = nil
                counterexampleID = nil
            }
            return try await RTLVerificationExecutionSupport.finalize(
                request: request,
                environment: environment,
                startedAt: startedAt,
                requestedStatus: status,
                diagnostics: [],
                analysisResult: RTLVerificationAnalysisResult(
                    findings: findings,
                    coverage: coverage,
                    proofStatus: comparison.mismatches.isEmpty && unsupported.isEmpty ? "proved" : "unproven",
                    counterexampleData: counterexampleData,
                    counterexampleArtifactID: counterexampleID
                )
            )
        } catch let error as RTLVerificationExecutionError {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: error
            )
        }
    }

}
