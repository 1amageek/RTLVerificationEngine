import Foundation
import LogicIR
import RTLVerificationCore
import XcircuitePackage

public struct NativeCDCAnalyzer: CDCAnalyzing {
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
        guard request.analysis == .cdc else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("CDC analysis requires analysis=cdc.")
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
            let clockDomains = Array(Set(analysis.clockDomains + constraintContext.clockNames)).sorted()
            let coverage = RTLVerificationCoverage(
                totalConstructs: parsed.constructCount,
                analyzedConstructs: parsed.analyzedConstructCount,
                unsupportedConstructs: parsed.unsupportedConstructs,
                clockDomains: clockDomains,
                resetDomains: [],
                proofScope: "clock-domain-crossing",
                limitations: parsed.unsupportedConstructs.map { "Unsupported construct: \($0)" }
                    + (constraintContext.exceptionCount > 0
                        ? ["SDC path exceptions are recorded for audit; native CDC does not treat them as safety waivers."]
                        : []),
                sourceArtifacts: parsed.sourceArtifacts + (constraintContext.sourceArtifact.map { [$0] } ?? []),
                constraintModes: constraintContext.modeIDs,
                constrainedClockDomains: constraintContext.clockNames,
                constraintExceptionCount: constraintContext.exceptionCount,
                constraintExceptionKinds: constraintContext.exceptionKinds,
                asynchronousClockGroups: constraintContext.asynchronousClockGroups
            )
            let requestedStatus: XcircuiteEngineExecutionStatus = analysis.hasUnresolvedClock ? .blocked : .completed
            let diagnostics = analysis.hasUnresolvedClock ? [XcircuiteEngineDiagnostic(
                severity: .error,
                code: "CDC_CLOCK_DOMAIN_UNRESOLVED",
                message: "At least one sequential process has no resolvable clock domain.",
                suggestedActions: ["declare_clock_event", "add_clock_constraint"]
            )] : []
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
        var hasUnresolvedClock: Bool
    }

    private func analyze(
        _ design: RTLDesign,
        constraintContext: RTLVerificationConstraintContext
    ) -> Analysis {
        var findings: [RTLVerificationFinding] = []
        var clockDomains: Set<String> = []
        var unresolvedClock = false

        for module in design.modules {
            var signalDomains: [String: String] = [:]
            for process in module.processes {
                guard process.kind == .sequential else { continue }
                guard let clock = RTLVerificationAnalysisHelpers.clockName(for: process) else {
                    unresolvedClock = true
                    continue
                }
                clockDomains.insert(clock)
                if !constraintContext.clockNames.isEmpty,
                   !constraintContext.containsClock(clock) {
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "CDC_CLOCK_UNCONSTRAINED",
                        message: "The inferred clock is not declared in the supplied timing constraints.",
                        entity: "\(module.name).\(clock)",
                        suggestedActions: ["declare_clock_in_sdc", "verify_clock_source"]
                    ))
                }
                let assignments = RTLVerificationAnalysisHelpers.assignments(in: process.statements)
                for (index, assignment) in assignments.enumerated() {
                    guard let target = RTLVerificationAnalysisHelpers.expressionBaseName(assignment.target) else { continue }
                    let sourceNames = RTLVerificationAnalysisHelpers.expressionNames(assignment.value)
                    signalDomains[target] = clock
                    for source in sourceNames {
                        guard source != clock, source != "" else { continue }
                        if let sourceDomain = signalDomains[source], sourceDomain == clock {
                            continue
                        }
                        let isExternal = signalDomains[source] == nil
                        let hasSecondStage = assignments.dropFirst(index + 1).contains { later in
                            RTLVerificationAnalysisHelpers.expressionNames(later.value).contains(target)
                        }
                        if hasSecondStage {
                            findings.append(RTLVerificationFinding(
                                severity: .info,
                                code: "CDC_SYNCHRONIZER_RECOGNIZED",
                                message: "A two-stage destination-domain synchronizer pattern was recognized.",
                                entity: "\(module.name).\(target)",
                                suggestedActions: ["retain_synchronizer_structure"]
                            ))
                        } else {
                            findings.append(RTLVerificationFinding(
                                severity: .error,
                                code: isExternal ? "CDC_ASYNCHRONOUS_INPUT" : "CDC_UNSAFE_CROSSING",
                                message: isExternal ? "An asynchronous signal enters a clock domain without a recognized synchronizer." : "A signal crosses clock domains without a recognized synchronizer.",
                                entity: "\(module.name).\(target)",
                                location: RTLVerificationExecutionSupport.sourceLocation(assignment.source),
                                suggestedActions: ["add_two_stage_synchronizer", "declare_clock_domain"]
                            ))
                        }
                    }
                }
            }

            for process in module.processes where process.kind == .sequential {
                guard let destinationClock = RTLVerificationAnalysisHelpers.clockName(for: process) else { continue }
                let assignments = RTLVerificationAnalysisHelpers.assignments(in: process.statements)
                let externalSources = assignments.flatMap { RTLVerificationAnalysisHelpers.expressionNames($0.value) }
                    .filter { signalDomainsFor(module: module)[$0] == nil && $0 != destinationClock }
                if Set(externalSources).count > 1 {
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "CDC_RECONVERGENCE",
                        message: "Multiple asynchronous sources reconverge in one destination clock domain.",
                        entity: "\(module.name).\(destinationClock)",
                        suggestedActions: ["synchronize_sources_independently", "avoid_reconvergence"]
                    ))
                }
            }
        }

        return Analysis(findings: findings, clockDomains: Array(clockDomains), hasUnresolvedClock: unresolvedClock)
    }

    private func signalDomainsFor(module: RTLModule) -> [String: String] {
        var result: [String: String] = [:]
        for process in module.processes where process.kind == .sequential {
            guard let clock = RTLVerificationAnalysisHelpers.clockName(for: process) else { continue }
            for assignment in RTLVerificationAnalysisHelpers.assignments(in: process.statements) {
                if let target = RTLVerificationAnalysisHelpers.expressionBaseName(assignment.target) {
                    result[target] = clock
                }
            }
        }
        return result
    }
}
