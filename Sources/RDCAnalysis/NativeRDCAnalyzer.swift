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
            let intentContext = try RTLResetIntentLoader(reader: environment.reader).load(
                request: request
            )
            let analysis = analyze(
                parsed.design,
                constraintContext: constraintContext,
                resetIntent: intentContext?.reset
            )
            var sourceArtifacts = parsed.sourceArtifacts
                + (constraintContext.sourceArtifact.map { [$0] } ?? [])
            for reference in [
                request.resetIntent?.artifact,
                request.powerIntent?.artifact,
            ].compactMap({ $0 }) {
                sourceArtifacts.append(RTLVerificationSourceArtifact(
                    path: reference.path,
                    sha256: reference.digest.hexadecimalValue,
                    byteCount: Int64(clamping: reference.byteCount),
                    order: sourceArtifacts.count
                ))
            }
            let coverage = RTLVerificationCoverage(
                totalConstructs: parsed.constructCount,
                analyzedConstructs: parsed.analyzedConstructCount,
                unsupportedConstructs: parsed.unsupportedConstructs,
                clockDomains: Array(Set(analysis.clockDomains + constraintContext.clockNames)).sorted(),
                resetDomains: analysis.resetDomains,
                resetReleaseDomains: analysis.resetReleaseDomains,
                proofScope: "reset-domain-crossing",
                limitations: parsed.unsupportedConstructs.map { "Unsupported construct: \($0)" }
                    + (intentContext == nil
                        ? ["Cross-domain reset release requires artifact-bound reset and canonical power intent."]
                        : [])
                    + (constraintContext.exceptionCount > 0
                        ? ["SDC path exceptions are evaluated explicitly and never act as implicit reset-safety waivers."]
                        : []),
                sourceArtifacts: sourceArtifacts,
                constraintModes: constraintContext.modeIDs,
                constrainedClockDomains: constraintContext.clockNames,
                constraintExceptionCount: constraintContext.exceptionCount,
                constraintExceptionKinds: constraintContext.exceptionKinds,
                asynchronousClockGroups: constraintContext.asynchronousClockGroups
            )
            let requestedStatus: RTLExecutionStatus = analysis.resetDomains.isEmpty
                || analysis.hasUnresolvedClock
                || analysis.hasIncompleteIntent
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
        var hasIncompleteIntent: Bool
    }

    private func analyze(
        _ design: RTLDesign,
        constraintContext: RTLVerificationConstraintContext,
        resetIntent: RTLResetIntent?
    ) -> Analysis {
        var findings: [RTLVerificationFinding] = []
        var clocks: Set<String> = []
        var resetToClocks: [String: Set<String>] = [:]
        var resetReleaseToClocks: [String: Set<String>] = [:]
        var resetUnsynchronizedToClocks: [String: Set<String>] = [:]
        var resetDomains: Set<String> = []
        var resetReleaseDomains: Set<String> = []
        var unresolvedClock = false
        var incompleteIntent = false
        var resetEventEdges: [String: Set<RTLClockEdge>] = [:]
        var releaseStageCounts: [String: Int] = [:]
        let resetIntentDomains = Dictionary(
            uniqueKeysWithValues: (resetIntent?.domains ?? []).map {
                ("\($0.resetSignal)@\($0.clockSignal)", $0)
            }
        )
        let acceptedExceptionDomains = Set(
            (resetIntent?.exceptions ?? []).map {
                "\($0.resetSignal)@\($0.clockSignal)"
            }
        )

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
                        let stageCount = resetReleaseStageCount(process, reset: reset)
                        releaseStageCounts[domain] = max(
                            releaseStageCounts[domain, default: 0],
                            stageCount
                        )
                        if stageCount >= 2 {
                            resetReleaseToClocks[reset, default: []].insert(clock)
                        } else {
                            resetUnsynchronizedToClocks[reset, default: []].insert(clock)
                        }
                        let edges = process.events
                            .filter { $0.signal == reset }
                            .compactMap(\.edge)
                        resetEventEdges[domain, default: []].formUnion(edges)
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
                continue
            }
            guard resetIntent != nil else {
                resetReleaseDomains = resetReleaseDomains.filter {
                    !$0.hasPrefix("\(reset)@")
                }
                incompleteIntent = true
                findings.append(RTLVerificationFinding(
                    severity: .error,
                    code: "RDC_RESET_INTENT_REQUIRED",
                    message: "Structurally synchronized cross-domain reset release requires artifact-bound reset waveform and canonical power-domain intent.",
                    entity: reset,
                    suggestedActions: ["attach_reset_intent", "attach_power_intent"]
                ))
                continue
            }
            resetReleaseDomains = resetReleaseDomains.filter {
                !$0.hasPrefix("\(reset)@")
            }
            for clock in resetClocks.sorted() {
                let domainKey = "\(reset)@\(clock)"
                guard let domainIntent = resetIntentDomains[domainKey] else {
                    incompleteIntent = true
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "RDC_RESET_DOMAIN_INTENT_MISSING",
                        message: "Reset intent does not declare the inferred reset and clock domain.",
                        entity: domainKey,
                        suggestedActions: ["declare_reset_domain_intent"]
                    ))
                    continue
                }
                if domainIntent.assertionMode != .asynchronous {
                    incompleteIntent = true
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "RDC_SYNCHRONOUS_ASSERTION_UNSUPPORTED",
                        message: "The native RDC backend cannot prove synchronous reset assertion semantics.",
                        entity: domainKey,
                        suggestedActions: ["select_temporal_rdc_backend"]
                    ))
                    continue
                }
                let expectedEdge: RTLClockEdge = domainIntent.polarity == .activeLow
                    ? .negative
                    : .positive
                guard resetEventEdges[domainKey, default: []] == Set([expectedEdge]) else {
                    incompleteIntent = true
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "RDC_RESET_POLARITY_MISMATCH",
                        message: "Reset sensitivity does not match the declared active polarity.",
                        entity: domainKey,
                        suggestedActions: ["repair_reset_polarity", "repair_reset_intent"]
                    ))
                    continue
                }
                let actualStages = releaseStageCounts[domainKey, default: 0]
                if actualStages < domainIntent.minimumReleaseStages,
                   !acceptedExceptionDomains.contains(domainKey) {
                    incompleteIntent = true
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "RDC_RELEASE_STAGE_REQUIREMENT_UNMET",
                        message: "Reset release has \(actualStages) structural stages but intent requires \(domainIntent.minimumReleaseStages).",
                        entity: domainKey,
                        suggestedActions: ["add_reset_release_stages", "attach_qualified_reset_exception"]
                    ))
                    continue
                }
                resetReleaseDomains.insert(domainKey)
            }
        }
        for (reset, resetClocks) in resetToClocks where resetClocks.count == 1 {
            let clock = resetClocks.first ?? "unknown-clock"
            if resetReleaseToClocks[reset, default: []].contains(clock),
               !resetUnsynchronizedToClocks[reset, default: []].contains(clock) {
                resetReleaseDomains.insert("\(reset)@\(clock)")
            }
        }
        for exception in constraintContext.exceptions {
            for reset in resetToClocks.keys where exception.references(reset) {
                incompleteIntent = true
                findings.append(RTLVerificationFinding(
                    severity: .error,
                    code: "RDC_SDC_EXCEPTION_NOT_RESET_WAIVER",
                    message: "An SDC \(exception.kind) path exception references a reset signal but cannot waive reset-domain safety.",
                    entity: reset,
                    suggestedActions: ["remove_reset_from_sdc_exception", "declare_typed_reset_exception"]
                ))
            }
        }
        if let resetIntent {
            for domain in resetIntent.domains {
                let key = "\(domain.resetSignal)@\(domain.clockSignal)"
                if !resetDomains.contains(key) {
                    incompleteIntent = true
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "RDC_RESET_INTENT_UNUSED",
                        message: "Reset intent contains a reset/clock domain that is absent from the canonical RTL.",
                        entity: key,
                        suggestedActions: ["remove_stale_reset_intent", "repair_rtl_reset_binding"]
                    ))
                }
            }
        }

        return Analysis(
            findings: findings,
            clockDomains: Array(clocks).sorted(),
            resetDomains: Array(resetDomains).sorted(),
            resetReleaseDomains: Array(resetReleaseDomains).sorted(),
            hasUnresolvedClock: unresolvedClock,
            hasIncompleteIntent: incompleteIntent
        )
    }

    private func resetReleaseStageCount(_ process: RTLProcess, reset: String) -> Int {
        resetReleaseStageCount(in: process.statements, reset: reset)
    }

    private func resetReleaseStageCount(
        in statements: [RTLStatement],
        reset: String
    ) -> Int {
        var maximum = 0
        for statement in statements {
            switch statement {
            case .conditional(let condition, let ifTrue, let ifFalse):
                if RTLVerificationAnalysisHelpers.expressionNames(condition).contains(reset) {
                    maximum = max(
                        maximum,
                        max(
                            resetReleaseBranchStageCount(ifTrue, ifFalse),
                            resetReleaseBranchStageCount(ifFalse, ifTrue)
                        )
                    )
                }
                maximum = max(
                    maximum,
                    max(
                        resetReleaseStageCount(in: ifTrue, reset: reset),
                        resetReleaseStageCount(in: ifFalse, reset: reset)
                    )
                )
            case .block(let children):
                maximum = max(
                    maximum,
                    resetReleaseStageCount(in: children, reset: reset)
                )
            case .typedCaseStatement(_, _, let items, let defaults):
                for item in items {
                    maximum = max(
                        maximum,
                        resetReleaseStageCount(in: item.statements, reset: reset)
                    )
                }
                maximum = max(
                    maximum,
                    resetReleaseStageCount(in: defaults, reset: reset)
                )
            case .assignment, .null:
                continue
            }
        }
        return maximum
    }

    private func resetReleaseBranchStageCount(
        _ assertedBranch: [RTLStatement],
        _ releasedBranch: [RTLStatement]
    ) -> Int {
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
            return 0
        }

        let assertedValues = assertedAssignments.compactMap(integerValue(of:))
        guard assertedValues.count == assertedAssignments.count,
              let assertedValue = assertedValues.first,
              assertedValues.allSatisfy({ $0 == assertedValue }) else {
            return 0
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
        return hasReleaseConstant && hasStageDependency ? assertedTargets.count : 0
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
