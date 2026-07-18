import CDCAnalysis
import FormalEquivalence
import Foundation
import RDCAnalysis
import RTLLint
import RTLVerificationCore

public struct RTLVerificationEngine: RTLVerificationExecuting {
    public static let capabilities: [RTLVerificationCapability] = [
        RTLVerificationCapability(
            engineID: RTLVerificationAnalysis.lint.stageID,
            schemaVersion: RTLVerificationCapability.currentSchemaVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: [
                "semantic-lint",
                "connectivity-lint",
                "width-lint",
                "combinational-loop-detection",
                "versioned-rule-catalog"
            ],
            limitations: ["SystemVerilog support is intentionally subset-scoped."]
        ),
        RTLVerificationCapability(
            engineID: RTLVerificationAnalysis.cdc.stageID,
            schemaVersion: RTLVerificationCapability.currentSchemaVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: [
                "clock-domain-inference",
                "synchronizer-recognition",
                "reconvergence-detection"
            ],
            limitations: [
                "Clock-domain inference requires recognizable sequential event controls; supplied SDC clocks are checked for declaration coverage."
            ]
        ),
        RTLVerificationCapability(
            engineID: RTLVerificationAnalysis.rdc.stageID,
            schemaVersion: RTLVerificationCapability.currentSchemaVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: [
                "reset-domain-inference",
                "reset-release-crossing-detection"
            ],
            limitations: [
                "Reset release is recognized only from a conservative structural synchronizer pattern; waveform, UPF and process-specific intent are not inferred."
            ]
        ),
        RTLVerificationCapability(
            engineID: RTLVerificationAnalysis.formalEquivalence.stageID,
            schemaVersion: RTLVerificationCapability.currentSchemaVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: [
                "canonical-structural-equivalence",
                "rtl-to-mapped-execution-structural-equivalence",
                "counterexample-artifact",
                "explicit-proof-view"
            ],
            limitations: [
                "Solver-backed temporal equivalence for synthesized and DFT views is outside the native proof scope."
            ]
        )
    ]

    public var lintEngine: any RTLLintExecuting
    public var cdcAnalyzer: any CDCAnalyzing
    public var rdcAnalyzer: any RDCAnalyzing
    public var equivalenceChecker: any FormalEquivalenceChecking

    public init(
        lintEngine: any RTLLintExecuting,
        cdcAnalyzer: any CDCAnalyzing,
        rdcAnalyzer: any RDCAnalyzing,
        equivalenceChecker: any FormalEquivalenceChecking
    ) {
        self.lintEngine = lintEngine
        self.cdcAnalyzer = cdcAnalyzer
        self.rdcAnalyzer = rdcAnalyzer
        self.equivalenceChecker = equivalenceChecker
    }

    public init(environment: RTLVerificationEnvironment) {
        self.init(
            lintEngine: NativeRTLLintEngine(environment: environment),
            cdcAnalyzer: NativeCDCAnalyzer(environment: environment),
            rdcAnalyzer: NativeRDCAnalyzer(environment: environment),
            equivalenceChecker: NativeFormalEquivalenceChecker(environment: environment)
        )
    }

    public func execute(
        _ request: RTLVerificationRequest
    ) async throws -> RTLVerificationResult {
        switch request.analysis {
        case .lint:
            return try await lintEngine.execute(request)
        case .cdc:
            return try await cdcAnalyzer.execute(request)
        case .rdc:
            return try await rdcAnalyzer.execute(request)
        case .formalEquivalence:
            return try await equivalenceChecker.execute(request)
        }
    }
}
