import Foundation
import CircuiteFoundation
import LogicIR
import RTLVerificationCore

public struct NativeRTLLintEngine: RTLLintExecuting {
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
        guard request.analysis == .lint else {
            return try await RTLVerificationExecutionSupport.blockedResult(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("RTLLint requires analysis=lint.")
            )
        }
        if Task.isCancelled {
            return try await cancelledResult(request: request, startedAt: startedAt)
        }

        do {
            let parsed = try RTLVerificationDesignLoader(reader: environment.reader, parser: environment.parser).load(request)
            let findings = lint(parsed.design)
            let coverage = RTLVerificationCoverage(
                totalConstructs: parsed.constructCount,
                analyzedConstructs: parsed.analyzedConstructCount,
                unsupportedConstructs: parsed.unsupportedConstructs,
                clockDomains: clockDomains(in: parsed.design),
                resetDomains: resetDomains(in: parsed.design),
                proofScope: "lint",
                limitations: parsed.unsupportedConstructs.map { "Unsupported construct: \($0)" },
                sourceArtifacts: parsed.sourceArtifacts
            )
            return try await RTLVerificationExecutionSupport.finalize(
                request: request,
                environment: environment,
                startedAt: startedAt,
                requestedStatus: .completed,
                diagnostics: [],
                analysisResult: RTLVerificationAnalysisResult(
                    findings: findings,
                    coverage: coverage
                )
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

    private func lint(_ design: RTLDesign) -> [RTLVerificationFinding] {
        var findings: [RTLVerificationFinding] = []
        let validator = LogicDesignValidator()
        for diagnostic in validator.validate(design).diagnostics {
            findings.append(RTLVerificationFinding(
                severity: Self.severity(from: diagnostic.severity),
                code: diagnostic.code,
                message: diagnostic.message,
                entity: diagnostic.entity,
                location: RTLVerificationExecutionSupport.sourceLocation(diagnostic.location),
                suggestedActions: diagnostic.suggestedActions
            ))
        }

        for module in design.modules {
            let widths = RTLVerificationAnalysisHelpers.widths(in: module)
            let assignments = RTLVerificationAnalysisHelpers.allAssignments(in: module)
            var drivers: [String: [RTLAssignment]] = [:]
            for assignment in assignments {
                guard let target = RTLVerificationAnalysisHelpers.expressionBaseName(assignment.target) else { continue }
                drivers[target, default: []].append(assignment)
                if let targetWidth = widths[target], let valueWidth = RTLVerificationAnalysisHelpers.expressionWidth(assignment.value, widths: widths), targetWidth != valueWidth {
                    findings.append(RTLVerificationFinding(
                        severity: .error,
                        code: "RTL_WIDTH_MISMATCH",
                        message: "The assignment width does not match the target width.",
                        entity: "\(module.name).\(target)",
                        location: RTLVerificationExecutionSupport.sourceLocation(assignment.source),
                        suggestedActions: ["resize_expression", "declare_matching_width"]
                    ))
                }
            }
            for (target, targetDrivers) in drivers where targetDrivers.count > 1 {
                findings.append(RTLVerificationFinding(
                    severity: .error,
                    code: "RTL_MULTIPLE_DRIVER",
                    message: "A signal has more than one procedural or continuous driver.",
                    entity: "\(module.name).\(target)",
                    suggestedActions: ["merge_drivers", "use_one_driver_per_signal"]
                ))
            }
            for process in module.processes where process.kind == .sequential {
                for assignment in RTLVerificationAnalysisHelpers.assignments(in: process.statements) where !assignment.nonBlocking {
                    findings.append(RTLVerificationFinding(
                        severity: .warning,
                        code: "RTL_SEQUENTIAL_BLOCKING_ASSIGNMENT",
                        message: "A sequential process uses a blocking assignment.",
                        entity: "\(module.name).\(process.id)",
                        location: RTLVerificationExecutionSupport.sourceLocation(assignment.source),
                        suggestedActions: ["use_nonblocking_assignment"]
                    ))
                }
            }
            findings.append(contentsOf: combinationalLoopFindings(module: module))
            let assignedOutputs = Set(assignments.compactMap { RTLVerificationAnalysisHelpers.expressionBaseName($0.target) })
            for port in module.ports where port.direction == .output && !assignedOutputs.contains(port.name) {
                findings.append(RTLVerificationFinding(
                    severity: .warning,
                    code: "RTL_OUTPUT_UNDRIVEN",
                    message: "An output port has no assignment in the analyzed RTL.",
                    entity: "\(module.name).\(port.name)",
                    location: RTLVerificationExecutionSupport.sourceLocation(port.source),
                    suggestedActions: ["drive_output", "confirm_intentional_constant"]
                ))
            }
        }
        return findings
    }

    private static func severity(from severity: DiagnosticSeverity) -> RTLDiagnosticSeverity {
        switch severity {
        case .information: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }

    private func combinationalLoopFindings(module: RTLModule) -> [RTLVerificationFinding] {
        var graph: [String: Set<String>] = [:]
        for assignment in module.assignments {
            guard let target = RTLVerificationAnalysisHelpers.expressionBaseName(assignment.target) else { continue }
            graph[target, default: []].formUnion(RTLVerificationAnalysisHelpers.expressionNames(assignment.value))
        }
        var findings: [RTLVerificationFinding] = []
        for start in graph.keys.sorted() where reaches(start, target: start, graph: graph, visited: []) {
            findings.append(RTLVerificationFinding(
                severity: .error,
                code: "RTL_COMBINATIONAL_LOOP",
                message: "A combinational assignment cycle was detected.",
                entity: "\(module.name).\(start)",
                suggestedActions: ["break_feedback_path", "add_sequential_storage"]
            ))
        }
        return findings
    }

    private func reaches(_ current: String, target: String, graph: [String: Set<String>], visited: Set<String>) -> Bool {
        guard let neighbors = graph[current] else { return false }
        for neighbor in neighbors {
            if neighbor == target { return true }
            if !visited.contains(neighbor) {
                var nextVisited = visited
                nextVisited.insert(neighbor)
                if reaches(neighbor, target: target, graph: graph, visited: nextVisited) { return true }
            }
        }
        return false
    }

    private func clockDomains(in design: RTLDesign) -> [String] {
        Array(Set(design.modules.flatMap { $0.processes.compactMap { RTLVerificationAnalysisHelpers.clockName(for: $0) } })).sorted()
    }

    private func resetDomains(in design: RTLDesign) -> [String] {
        Array(Set(design.modules.flatMap { $0.processes.flatMap { RTLVerificationAnalysisHelpers.resetNames(for: $0) } })).sorted()
    }

    private func cancelledResult(
        request: RTLVerificationRequest,
        startedAt: Date
    ) async throws -> RTLVerificationResult {
        try await RTLVerificationExecutionSupport.finalize(
            request: request,
            environment: environment,
            startedAt: startedAt,
            requestedStatus: .cancelled,
            diagnostics: [RTLDiagnostic(
                severity: .warning,
                code: "RTL_EXECUTION_CANCELLED",
                message: "RTL lint execution was cancelled before analysis started.",
                suggestedActions: ["resume_run"]
            )],
            analysisResult: RTLVerificationAnalysisResult(
                coverage: RTLVerificationCoverage(proofScope: "cancelled")
            )
        )
    }
}
