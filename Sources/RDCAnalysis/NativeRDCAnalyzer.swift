import Foundation
import LogicIR
import RTLVerificationCore

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
    ) async throws -> RTLVerificationResult {
        let startedAt = Date()
        guard request.analysis == .rdc else {
            return try await RTLVerificationExecutionSupport.blockedResult(
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
                resetReleaseDomains: analysis.resetReleaseDomains,
                proofScope: "reset-domain-crossing",
                limitations: parsed.unsupportedConstructs.map { "Unsupported construct: \($0)" }
                    + ["Reset release evidence is limited to a conservative structural synchronizer pattern; temporal and process record remain separate."]
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
            let requestedStatus: RTLExecutionStatus = analysis.resetDomains.isEmpty || analysis.hasUnresolvedClock
                ? .blocked
                : .completed
            var diagnostics: [RTLDiagnostic] = []
            if analysis.resetDomains.isEmpty {
                diagnostics.append(RTLDiagnostic(
                    severity: .error,
                    code: "RDC_RESET_DOMAIN_UNRESOLVED",
                    message: "No reset domain could be inferred from the sequential RTL.",
                    suggestedActions: ["declare_reset_event", "add_reset_constraint"]
                ))
            }
            if analysis.hasUnresolvedClock {
                diagnostics.append(RTLDiagnostic(
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
            return try await RTLVerificationExecutionSupport.blockedResult(
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
        var resetReleaseDomains: [String]
        var hasUnresolvedClock: Bool
    }

    private func analyze(
        _ design: RTLDesign,
        constraintContext: RTLVerificationConstraintContext
    ) -> Analysis {
        var findings: [RTLVerificationFinding] = []
        var clocks: Set<String> = []
        var resetToClocks: [String: Set<String>] = [:]
        var resetReleaseToClocks: [String: Set<String>] = [:]
        var resetUnsynchronizedToClocks: [String: Set<String>] = [:]
        var resetDomains: Set<String> = []
        var resetReleaseDomains: Set<String> = []
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
                    if let clock {
                        if isResetReleaseSynchronizer(process, reset: reset) {
                            resetReleaseToClocks[reset, default: []].insert(clock)
                        } else {
                            resetUnsynchronizedToClocks[reset, default: []].insert(clock)
                        }
                    }
                }
            }
        }

        for (reset, synchronizedClocks) in resetReleaseToClocks {
            let unsynchronizedClocks = resetUnsynchronizedToClocks[reset, default: []]
            for clock in synchronizedClocks where !unsynchronizedClocks.contains(clock) {
                resetReleaseDomains.insert("\(reset)@\(clock)")
            }
        }
        for (reset, resetClocks) in resetToClocks where resetClocks.count > 1 {
            let synchronizedClocks = resetReleaseToClocks[reset, default: []]
            let unsynchronizedClocks = resetUnsynchronizedToClocks[reset, default: []]
            if synchronizedClocks != resetClocks || !unsynchronizedClocks.isEmpty {
                findings.append(RTLVerificationFinding(
                    severity: .error,
                    code: "RDC_UNSAFE_RESET_CROSSING",
                    message: "A reset signal is used by multiple clock domains without a recognized release synchronizer in every domain.",
                    entity: reset,
                    suggestedActions: ["synchronize_reset_release", "declare_reset_relationship"]
                ))
            }
        }

        return Analysis(
            findings: findings,
            clockDomains: Array(clocks).sorted(),
            resetDomains: Array(resetDomains).sorted(),
            resetReleaseDomains: Array(resetReleaseDomains).sorted(),
            hasUnresolvedClock: unresolvedClock
        )
    }

    private func isResetReleaseSynchronizer(_ process: RTLProcess, reset: String) -> Bool {
        containsResetReleaseSynchronizer(in: process.statements, reset: reset)
    }

    private func containsResetReleaseSynchronizer(
        in statements: [RTLStatement],
        reset: String
    ) -> Bool {
        for statement in statements {
            switch statement {
            case .conditional(let condition, let ifTrue, let ifFalse):
                if RTLVerificationAnalysisHelpers.expressionNames(condition).contains(reset),
                   (isResetReleaseBranchPair(ifTrue, ifFalse) || isResetReleaseBranchPair(ifFalse, ifTrue)) {
                    return true
                }
                if containsResetReleaseSynchronizer(in: ifTrue, reset: reset)
                    || containsResetReleaseSynchronizer(in: ifFalse, reset: reset) {
                    return true
                }
            case .block(let children):
                if containsResetReleaseSynchronizer(in: children, reset: reset) {
                    return true
                }
            case .caseStatement(_, let items, let defaults),
                 .typedCaseStatement(_, _, let items, let defaults):
                if items.contains(where: { containsResetReleaseSynchronizer(in: $0.statements, reset: reset) })
                    || containsResetReleaseSynchronizer(in: defaults, reset: reset) {
                    return true
                }
            case .assignment, .null:
                continue
            }
        }
        return false
    }

    private func isResetReleaseBranchPair(
        _ assertedBranch: [RTLStatement],
        _ releasedBranch: [RTLStatement]
    ) -> Bool {
        let assertedAssignments = RTLVerificationAnalysisHelpers.assignments(in: assertedBranch)
        let releasedAssignments = RTLVerificationAnalysisHelpers.assignments(in: releasedBranch)
        let assertedTargets = Set(assertedAssignments.compactMap(targetName(of:)))
        let releasedTargets = Set(releasedAssignments.compactMap(targetName(of:)))
        guard assertedTargets.count >= 2,
              assertedTargets == releasedTargets,
              assertedAssignments.count == assertedTargets.count,
              releasedAssignments.count == releasedTargets.count,
              assertedAssignments.allSatisfy(\.nonBlocking),
              releasedAssignments.allSatisfy(\.nonBlocking) else {
            return false
        }

        let assertedValues = assertedAssignments.compactMap(integerValue(of:))
        guard assertedValues.count == assertedAssignments.count,
              let assertedValue = assertedValues.first,
              assertedValues.allSatisfy({ $0 == assertedValue }) else {
            return false
        }

        let hasReleaseConstant = releasedAssignments.contains { assignment in
            guard let value = integerValue(of: assignment) else { return false }
            return value != assertedValue
        }
        let hasStageDependency = releasedAssignments.contains { assignment in
            guard let target = targetName(of: assignment),
                  case .identifier(let source) = assignment.value else {
                return false
            }
            return target != source && releasedTargets.contains(source)
        }
        return hasReleaseConstant && hasStageDependency
    }

    private func targetName(of assignment: RTLAssignment) -> String? {
        guard case .identifier(let name) = assignment.target else { return nil }
        return name
    }

    private func integerValue(of assignment: RTLAssignment) -> Int64? {
        guard case .integer(let value, _, _) = assignment.value else { return nil }
        return value
    }
}
