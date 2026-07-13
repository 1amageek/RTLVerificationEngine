import Foundation
import CircuiteFoundation
import LogicIR
import SystemVerilogFrontend

public struct SystemVerilogRTLParser: RTLVerificationDesignParsing, RTLVerificationSourceSetParsing {
    public init() {}

    public func parse(
        data: Data,
        path: String,
        topModuleName: String
    ) throws -> RTLVerificationParsedDesign {
        try parse(
            sources: [RTLVerificationSourceInput(
                reference: try Self.makeReference(path: path, data: data, format: .systemVerilog),
                data: data
            )],
            topModuleName: topModuleName,
            options: RTLVerificationFrontendOptions()
        )
    }

    public func parse(
        data: Data,
        path: String,
        topModuleName: String,
        options: RTLVerificationFrontendOptions = RTLVerificationFrontendOptions()
    ) throws -> RTLVerificationParsedDesign {
        try parse(
            sources: [RTLVerificationSourceInput(
                reference: try Self.makeReference(
                    path: path,
                    data: data,
                    format: path.lowercased().hasSuffix(".v") ? .verilog : .systemVerilog
                ),
                data: data
            )],
            topModuleName: topModuleName,
            options: options
        )
    }

    public func parse(
        sources: [RTLVerificationSourceInput],
        topModuleName: String,
        options: RTLVerificationFrontendOptions
    ) throws -> RTLVerificationParsedDesign {
        guard !sources.isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest(
                "At least one RTL source is required for frontend parsing."
            )
        }
        let language = options.language.lowercased()
        guard language == "systemverilog" || language == "verilog" else {
            throw RTLVerificationExecutionError.parserFailed(
                path: sources[0].path,
                reason: "Unsupported RTL language \(options.language)."
            )
        }
        let includeSources = try Dictionary(uniqueKeysWithValues: sources.map { source in
            guard let text = String(data: source.data, encoding: .utf8) else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: source.path,
                    reason: "The source is not valid UTF-8."
                )
            }
            return (source.path, text)
        })
        var combinedSource = ""
        var linePaths: [String] = []
        var unsupportedDirectives: [String] = []
        let preprocessedSources = try sources.map { source in
            guard let text = includeSources[source.path] else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: source.path,
                    reason: "The source is not available to the frontend."
                )
            }
            let preprocessed = try SystemVerilogRTLPreprocessor().preprocess(
                text,
                path: source.path,
                options: options,
                includeSources: includeSources
            )
            return (source: source, preprocessed: preprocessed)
        }
        let includedPaths = Set(preprocessedSources.flatMap { $0.preprocessed.includedPaths })
        var emittedSourceIndex = 0
        for entry in preprocessedSources where !includedPaths.contains(entry.source.path) {
            let preprocessed = entry.preprocessed
            if emittedSourceIndex > 0 {
                combinedSource.append("\n")
                linePaths.append("")
            }
            combinedSource.append(preprocessed.source)
            linePaths.append(contentsOf: preprocessed.linePaths)
            unsupportedDirectives.append(contentsOf: preprocessed.unsupportedDirectives)
            emittedSourceIndex += 1
        }
        let sourceFiles = sources.enumerated().map { index, source in
            LogicSourceFile(
                path: source.path,
                sha256: RTLHasher().sha256(data: source.data),
                byteCount: Int64(source.data.count)
            )
        }
        return try parseCanonicalFrontend(
            source: combinedSource,
            linePaths: linePaths,
            fallbackPath: sources[0].path,
            topModuleName: topModuleName,
            requireTopModule: options.requireTopModule,
            unsupportedDirectives: unsupportedDirectives,
            sourceFiles: sourceFiles
        )
    }

    private static func makeReference(
        path: String,
        data: Data,
        format: ArtifactFormat
    ) throws -> RTLArtifactReference {
        ArtifactReference(
            id: ArtifactID(stableKey: "rtl-source:\(path)"),
            locator: ArtifactLocator(
                location: try ArtifactLocation(workspaceRelativePath: path),
                role: .input,
                kind: .rtl,
                format: format
            ),
            digest: try SHA256ContentDigester().digest(data: data),
            byteCount: UInt64(data.count)
        )
    }

    private func parseCanonicalFrontend(
        source: String,
        linePaths: [String],
        fallbackPath: String,
        topModuleName: String,
        requireTopModule: Bool,
        unsupportedDirectives: [String],
        sourceFiles: [LogicSourceFile]
    ) throws -> RTLVerificationParsedDesign {
        let sourceUnit = SystemVerilogSourceUnit(
            path: fallbackPath,
            source: source
        )
        let result = SystemVerilogParser().parse(
            [sourceUnit],
            topDesignName: topModuleName
        )
        let unsupportedDiagnostics = result.diagnostics.filter {
            $0.code.hasPrefix("SV_UNSUPPORTED") || $0.code.hasPrefix("SV_DEFINE")
        }
        let parserDiagnostics = result.diagnostics.filter {
            !$0.code.hasPrefix("SV_UNSUPPORTED") && !$0.code.hasPrefix("SV_DEFINE")
        }
        if let diagnostic = parserDiagnostics.first(where: { $0.severity == .error }) {
            throw RTLVerificationExecutionError.parserFailed(
                path: diagnostic.location?.start.path ?? fallbackPath,
                reason: diagnostic.message
            )
        }
        guard var design = result.design else {
            throw RTLVerificationExecutionError.parserFailed(
                path: fallbackPath,
                reason: "No module declaration was found."
            )
        }

        guard !requireTopModule || !topModuleName.isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest(
                "A top module name is required by the frontend policy."
            )
        }
        let selectedTop = topModuleName.isEmpty ? design.modules[0].name : topModuleName
        guard design.modules.contains(where: { $0.name == selectedTop }) else {
            throw RTLVerificationExecutionError.parserFailed(
                path: fallbackPath,
                reason: "Top module \(selectedTop) was not found in the RTL source set."
            )
        }
        design.topModuleName = selectedTop
        var elaboratedDesign = RTLGenerateElaborator().elaborate(design)
        let topHasInstances = elaboratedDesign.modules
            .first(where: { $0.name == selectedTop })?
            .instances
            .isEmpty == false
        if topHasInstances {
            let hierarchyResult = RTLHierarchyElaborator().elaborate(elaboratedDesign)
            guard let flattenedDesign = hierarchyResult.design else {
                let diagnostic = hierarchyResult.diagnostics.first
                throw RTLVerificationExecutionError.parserFailed(
                    path: diagnostic?.location?.start.path ?? fallbackPath,
                    reason: diagnostic.map { "\($0.code): \($0.message)" }
                        ?? "RTL hierarchy elaboration failed."
                )
            }
            elaboratedDesign = flattenedDesign
        }
        design = elaboratedDesign
        design.sourceFiles = sourceFiles
        remapSourcePaths(
            in: &design,
            linePaths: linePaths,
            fallbackPath: fallbackPath
        )
        var unsupported = unsupportedDirectives
        unsupported.append(contentsOf: unsupportedDiagnostics.map { diagnostic in
            if let entity = diagnostic.entity, !entity.isEmpty {
                return "\(diagnostic.code):\(entity)"
            }
            return diagnostic.code
        })
        if result.unsupportedSemantics && unsupported.isEmpty {
            unsupported.append("canonical-frontend-unsupported-semantics")
        }
        return RTLVerificationParsedDesign(
            design: design,
            sourcePaths: sourceFiles.map(\.path),
            constructCount: Tokenizer.tokenize(source).count,
            unsupportedConstructs: unsupported,
            sourceArtifacts: sourceFiles.enumerated().map { index, file in
                RTLVerificationSourceArtifact(
                    path: file.path,
                    sha256: file.sha256,
                    byteCount: file.byteCount,
                    order: index
                )
            }
        )
    }

    private func remapSourcePaths(
        in design: inout RTLDesign,
        linePaths: [String],
        fallbackPath: String
    ) {
        for moduleIndex in design.modules.indices {
            var module = design.modules[moduleIndex]
            module.source = remap(module.source, linePaths: linePaths, fallbackPath: fallbackPath)
            module.parameters = module.parameters.map { parameter in
                var parameter = parameter
                parameter.source = remap(parameter.source, linePaths: linePaths, fallbackPath: fallbackPath)
                return parameter
            }
            module.ports = module.ports.map { port in
                var port = port
                port.source = remap(port.source, linePaths: linePaths, fallbackPath: fallbackPath)
                return port
            }
            module.signals = module.signals.map { signal in
                var signal = signal
                signal.source = remap(signal.source, linePaths: linePaths, fallbackPath: fallbackPath)
                return signal
            }
            module.memories = module.memories.map { memory in
                var memory = memory
                memory.source = remap(memory.source, linePaths: linePaths, fallbackPath: fallbackPath)
                return memory
            }
            module.assignments = module.assignments.map { assignment in
                remap(assignment, linePaths: linePaths, fallbackPath: fallbackPath)
            }
            module.processes = module.processes.map { process in
                remap(process, linePaths: linePaths, fallbackPath: fallbackPath)
            }
            module.instances = module.instances.map { instance in
                remap(instance, linePaths: linePaths, fallbackPath: fallbackPath)
            }
            module.generateBlocks = module.generateBlocks.map { block in
                remap(block, linePaths: linePaths, fallbackPath: fallbackPath)
            }
            design.modules[moduleIndex] = module
        }
    }

    private func remap(
        _ assignment: RTLAssignment,
        linePaths: [String],
        fallbackPath: String
    ) -> RTLAssignment {
        var assignment = assignment
        assignment.source = remap(assignment.source, linePaths: linePaths, fallbackPath: fallbackPath)
        return assignment
    }

    private func remap(
        _ process: RTLProcess,
        linePaths: [String],
        fallbackPath: String
    ) -> RTLProcess {
        var process = process
        process.source = remap(process.source, linePaths: linePaths, fallbackPath: fallbackPath)
        process.statements = process.statements.map { statement in
            remap(statement, linePaths: linePaths, fallbackPath: fallbackPath)
        }
        return process
    }

    private func remap(
        _ statement: RTLStatement,
        linePaths: [String],
        fallbackPath: String
    ) -> RTLStatement {
        switch statement {
        case .assignment(let assignment):
            return .assignment(remap(assignment, linePaths: linePaths, fallbackPath: fallbackPath))
        case .block(let statements):
            return .block(statements.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) })
        case .conditional(let condition, let ifTrue, let ifFalse):
            return .conditional(
                condition: condition,
                ifTrue: ifTrue.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) },
                ifFalse: ifFalse.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) }
            )
        case .caseStatement(let expression, let items, let defaults):
            return .caseStatement(
                expression: expression,
                items: items.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) },
                defaultStatements: defaults.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) }
            )
        case .typedCaseStatement(let kind, let expression, let items, let defaults):
            return .typedCaseStatement(
                kind: kind,
                expression: expression,
                items: items.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) },
                defaultStatements: defaults.map { remap($0, linePaths: linePaths, fallbackPath: fallbackPath) }
            )
        case .null:
            return .null
        }
    }

    private func remap(
        _ item: RTLCaseItem,
        linePaths: [String],
        fallbackPath: String
    ) -> RTLCaseItem {
        var item = item
        item.source = remap(item.source, linePaths: linePaths, fallbackPath: fallbackPath)
        item.statements = item.statements.map { statement in
            remap(statement, linePaths: linePaths, fallbackPath: fallbackPath)
        }
        return item
    }

    private func remap(
        _ instance: RTLInstance,
        linePaths: [String],
        fallbackPath: String
    ) -> RTLInstance {
        var instance = instance
        instance.source = remap(instance.source, linePaths: linePaths, fallbackPath: fallbackPath)
        instance.connections = instance.connections.map { connection in
            var connection = connection
            connection.source = remap(connection.source, linePaths: linePaths, fallbackPath: fallbackPath)
            return connection
        }
        return instance
    }

    private func remap(
        _ block: RTLGenerateBlock,
        linePaths: [String],
        fallbackPath: String
    ) -> RTLGenerateBlock {
        var block = block
        block.source = remap(block.source, linePaths: linePaths, fallbackPath: fallbackPath)
        block.instances = block.instances.map { instance in
            remap(instance, linePaths: linePaths, fallbackPath: fallbackPath)
        }
        block.assignments = block.assignments.map { assignment in
            remap(assignment, linePaths: linePaths, fallbackPath: fallbackPath)
        }
        return block
    }

    private func remap(
        _ span: LogicSourceSpan?,
        linePaths: [String],
        fallbackPath: String
    ) -> LogicSourceSpan? {
        guard var span else { return nil }
        span.start.path = path(for: span.start.line, linePaths: linePaths, fallbackPath: fallbackPath)
        span.end.path = path(for: span.end.line, linePaths: linePaths, fallbackPath: fallbackPath)
        return span
    }

    private func path(for line: Int, linePaths: [String], fallbackPath: String) -> String {
        guard line > 0, line <= linePaths.count else { return fallbackPath }
        let path = linePaths[line - 1]
        return path.isEmpty ? fallbackPath : path
    }

    private struct Token: Sendable, Hashable {
        var text: String
        var line: Int
        var column: Int
    }

    private enum Tokenizer {
        static func tokenize(_ source: String) -> [Token] {
            let characters = Array(source)
            var result: [Token] = []
            var index = 0
            var line = 1
            var column = 1

            func advance(_ character: Character) {
                if character == "\n" {
                    line += 1
                    column = 1
                } else {
                    column += 1
                }
            }

            while index < characters.count {
                let character = characters[index]
                if character.isWhitespace {
                    advance(character)
                    index += 1
                    continue
                }

                if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                    advance(character)
                    advance(characters[index + 1])
                    index += 2
                    while index < characters.count, characters[index] != "\n" {
                        advance(characters[index])
                        index += 1
                    }
                    continue
                }

                if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                    advance(character)
                    advance(characters[index + 1])
                    index += 2
                    while index + 1 < characters.count {
                        if characters[index] == "*", characters[index + 1] == "/" {
                            advance(characters[index])
                            advance(characters[index + 1])
                            index += 2
                            break
                        }
                        advance(characters[index])
                        index += 1
                    }
                    continue
                }

                if character == "`" {
                    while index < characters.count, characters[index] != "\n" {
                        advance(characters[index])
                        index += 1
                    }
                    continue
                }

                let startLine = line
                let startColumn = column
                if character.isLetter || character == "_" || character == "$" {
                    var value = String(character)
                    advance(character)
                    index += 1
                    while index < characters.count {
                        let next = characters[index]
                        guard next.isLetter || next.isNumber || next == "_" || next == "$" else { break }
                        value.append(next)
                        advance(next)
                        index += 1
                    }
                    result.append(Token(text: value, line: startLine, column: startColumn))
                    continue
                }

                if character.isNumber || character == "'" {
                    var value = String(character)
                    advance(character)
                    index += 1
                    while index < characters.count {
                        let next = characters[index]
                        guard next.isLetter || next.isNumber || next == "_" || next == "'" || next == "?" else { break }
                        value.append(next)
                        advance(next)
                        index += 1
                    }
                    result.append(Token(text: value, line: startLine, column: startColumn))
                    continue
                }

                if character == "\"" {
                    var value = ""
                    advance(character)
                    index += 1
                    while index < characters.count, characters[index] != "\"" {
                        value.append(characters[index])
                        advance(characters[index])
                        index += 1
                    }
                    if index < characters.count {
                        advance(characters[index])
                        index += 1
                    }
                    result.append(Token(text: "\"\(value)\"", line: startLine, column: startColumn))
                    continue
                }

                let twoCharacterOperators = ["<=", ">=", "==", "!=", "&&", "||", "<<", ">>", "->", "++", "--"]
                if index + 1 < characters.count {
                    let pair = String(characters[index...index + 1])
                    if twoCharacterOperators.contains(pair) {
                        result.append(Token(text: pair, line: startLine, column: startColumn))
                        advance(characters[index])
                        advance(characters[index + 1])
                        index += 2
                        continue
                    }
                }

                result.append(Token(text: String(character), line: startLine, column: startColumn))
                advance(character)
                index += 1
            }
            return result
        }
    }
}
