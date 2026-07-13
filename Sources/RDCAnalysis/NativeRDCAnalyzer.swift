import Foundation
import LogicIR
import RTLVerificationCore
import XcircuitePackage

public struct NativeRDCAnalyzer: RDCAnalyzing {
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
        guard request.analysis == .rdc else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("RDC analysis requires analysis=rdc.")
            )
        }
        do {
            let parsed = try RTLVerificationDesignLoader(reader: environment.reader, parser: environment.parser).load(request)
            let constraintContext: RTLVerificationConstraintContext
            if let constraints = request.constraints {
                constraintContext = try RTLVerificationConstraintLoader(reader: environment.reader).load(constraints)
            } else {
                constraintContext = RTLVerificationConstraintContext()
            }
            let analysis = analyze(parsed.design, constraintContext: constraintContext)
            let coverage = RTLVerificationCoverage(
                totalConstructs: parsed.constructCount,
                analyzedConstructs: parsed.analyzedConstructCount,
                unsupportedConstructs: parsed.unsupportedConstructs,
                clockDomains: Array(Set(analysis.clockDomains + constraintContext.clockNames)).sorted(),
                resetDomains: analysis.resetDomains,
                proofScope: "reset-domain-crossing",
                limitations: parsed.unsupportedConstructs.map { "Unsupported construct: \($0)" }
                    + (constraintContext.exceptionCount > 0
                        ? ["SDC path exceptions are recorded for audit; native RDC does not treat them as safety waivers."]
                        : []),
                sourceArtifacts: parsed.sourceArtifacts + (constraintContext.sourceArtifact.map { [$0] } ?? []),
                constraintModes: constraintContext.modeIDs,
                constrainedClockDomains: constraintContext.clockNames,
                constraintExceptionCount: constraintContext.exceptionCount,
                constraintExceptionKinds: constraintContext.exceptionKinds,
                asynchronousClockGroups: constraintContext.asynchronousClockGroups
            )
            let requestedStatus: XcircuiteEngineExecutionStatus = analysis.resetDomains.isEmpty || analysis.hasUnresolvedClock
                ? .blocked
                : .completed
            var diagnostics: [XcircuiteEngineDiagnostic] = []
            if analysis.resetDomains.isEmpty {
                diagnostics.append(XcircuiteEngineDiagnostic(
                    severity: .error,
                    code: "RDC_RESET_DOMAIN_UNRESOLVED",
                    message: "No reset domain could be inferred from the sequential RTL.",
                    suggestedActions: ["declare_reset_event", "add_reset_constraint"]
                ))
            }
            if analysis.hasUnresolvedClock {
                diagnostics.append(XcircuiteEngineDiagnostic(
                    severity: .error,
                    code: "RDC_CLOCK_DOMAIN_UNRESOLVED",
                    message: "At least one sequential reset process has no resolvable clock domain.",
                    suggestedActions: ["declare_clock_event", "add_clock_constraint"]
                ))
            }
            return try await RTLVerificationExecutionSupport.finalize(
                request: request,
                environment: environment,
                startedAt: startedAt,
                requestedStatus: requestedStatus,
                diagnostics: diagnostics,
                analysisResult: RTLVerificationAnalysisResult(findings: analysis.findings, coverage: coverage)
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

    private struct Analysis {
        var findings: [RTLVerificationFinding]
        var clockDomains: [String]
        var resetDomains: [String]
        var hasUnresolvedClock: Bool
    }

    private func analyze(
        _ design: RTLDesign,
        constraintContext: RTLVerificationConstraintContext
    ) -> Analysis {
        var findings: [RTLVerificationFinding] = []
        var clocks: Set<String> = []
        var resetToClocks: [String: Set<String>] = [:]
        var resetDomains: Set<String> = []
        var unresolvedClock = false

        for module in design.modules {
            for process in module.processes where process.kind == .sequential {
                let clock = RTLVerificationAnalysisHelpers.clockName(for: process)
                if let clock {
                    clocks.insert(clock)
                    if !constraintContext.clockNames.isEmpty,
                       !constraintContext.containsClock(clock) {
                        findings.append(RTLVerificationFinding(
                            severity: .error,
                            code: "RDC_CLOCK_UNCONSTRAINED",
                            message: "The inferred reset-process clock is not declared in the supplied timing constraints.",
                            entity: "\(module.name).\(clock)",
                            suggestedActions: ["declare_clock_in_sdc", "verify_clock_source"]
                        ))
                    }
                } else {
                    unresolvedClock = true
                }
                let resets = RTLVerificationAnalysisHelpers.resetNames(for: process)
                if resets.isEmpty {
                    findings.append(RTLVerificationFinding(
                        severity: .warning,
                        code: "RDC_RESET_MISSING",
                        message: "A sequential process has no recognized reset event.",
                        entity: "\(module.name).\(process.id)",
                        location: RTLVerificationExecutionSupport.sourceLocation(process.source),
                        suggestedActions: ["declare_reset_event", "document_resetless_state"]
                    ))
                }
                if resets.count > 1 {
                    findings.append(RTLVerificationFinding(
                        severity: .warning,
                        code: "RDC_MULTIPLE_RESET_EVENTS",
                        message: "A sequential process is sensitive to multiple reset signals.",
                        entity: "\(module.name).\(process.id)",
                        suggestedActions: ["define_reset_priority", "use_one_reset_domain"]
                    ))
                }
                for reset in resets {
                    let domain = "\(reset)@\(clock ?? "unknown-clock")"
                    resetDomains.insert(domain)
                    resetToClocks[reset, default: []].insert(clock ?? "unknown-clock")
                }
            }
        }

        for (reset, resetClocks) in resetToClocks where resetClocks.count > 1 {
            findings.append(RTLVerificationFinding(
                severity: .error,
                code: "RDC_UNSAFE_RESET_CROSSING",
                message: "A reset signal is used by multiple clock domains without a declared release relationship.",
                entity: reset,
                suggestedActions: ["synchronize_reset_release", "declare_reset_relationship"]
            ))
        }

        return Analysis(
            findings: findings,
            clockDomains: Array(clocks).sorted(),
            resetDomains: Array(resetDomains).sorted(),
            hasUnresolvedClock: unresolvedClock
        )
    }
}
