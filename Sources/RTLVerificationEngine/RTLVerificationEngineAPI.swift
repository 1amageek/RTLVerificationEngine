import Foundation
import RTLVerificationCore
import XcircuitePackage

public enum RTLVerificationEngineAPI {
    public static let contractVersion = 1
    public static let implementationVersion = RTLVerificationExecutionSupport.implementationVersion

    public static let capabilities: [RTLVerificationCapability] = [
        RTLVerificationCapability(
            engineID: "rtl.lint",
            contractVersion: contractVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: ["semantic-lint", "connectivity-lint", "width-lint", "combinational-loop-detection"],
            limitations: ["SystemVerilog support is intentionally subset-scoped."]
        ),
        RTLVerificationCapability(
            engineID: "rtl.cdc",
            contractVersion: contractVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: ["clock-domain-inference", "synchronizer-recognition", "reconvergence-detection"],
            limitations: ["Clock-domain inference requires recognizable sequential event controls; supplied SDC clocks are checked for declaration coverage."]
        ),
        RTLVerificationCapability(
            engineID: "rtl.rdc",
            contractVersion: contractVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: ["reset-domain-inference", "reset-release-crossing-detection"],
            limitations: ["Reset sequencing constraints are not inferred from waveforms."]
        ),
        RTLVerificationCapability(
            engineID: "rtl.equivalence",
            contractVersion: contractVersion,
            supportedInputFormats: [.systemVerilog, .verilog, .json],
            supportedOutputFormats: [.json],
            features: ["canonical-structural-equivalence", "rtl-to-mapped-execution-structural-equivalence", "counterexample-artifact", "explicit-proof-view"],
            limitations: ["Solver-backed temporal equivalence for synthesized and DFT views is outside the native proof scope."]
        ),
    ]
}
