import Foundation
import LogicIR
import XcircuitePackage

public struct SystemVerilogRTLParser: RTLVerificationDesignParsing, RTLVerificationSourceSetParsing {
    public init() {}

    public func parse(
        data: Data,
        path: String,
        topModuleName: String
    ) throws -> RTLVerificationParsedDesign {
        try parse(
            sources: [RTLVerificationSourceInput(
                reference: XcircuiteFileReference(
                    path: path,
                    kind: .rtl,
                    format: .systemVerilog
                ),
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
                reference: XcircuiteFileReference(
                    path: path,
                    kind: .rtl,
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
                sha256: XcircuiteHasher().sha256(data: source.data),
                byteCount: Int64(source.data.count)
            )
        }
        let combinedData = Data(combinedSource.utf8)
        let tokens = Tokenizer.tokenize(combinedSource)
        var parser = Parser(
            tokens: tokens,
            path: sources[0].path,
            topModuleName: topModuleName,
            linePaths: linePaths,
            sourceFiles: sourceFiles
        )
        return try parser.parse(
            data: combinedData,
            unsupportedDirectives: unsupportedDirectives,
            sourceFiles: sourceFiles
        )
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

    private struct Parser {
        var tokens: [Token]
        var index: Int = 0
        let path: String
        let topModuleName: String
        let linePaths: [String]
        let sourceFiles: [LogicSourceFile]
        var unsupportedConstructs: [String] = []

        init(
            tokens: [Token],
            path: String,
            topModuleName: String,
            linePaths: [String] = [],
            sourceFiles: [LogicSourceFile] = []
        ) {
            self.tokens = tokens
            self.path = path
            self.topModuleName = topModuleName
            self.linePaths = linePaths
            self.sourceFiles = sourceFiles
        }

        mutating func parse(
            data: Data,
            unsupportedDirectives: [String],
            sourceFiles: [LogicSourceFile]
        ) throws -> RTLVerificationParsedDesign {
            var modules: [RTLModule] = []
            let unsupportedKeywords = [
                "interface", "class", "package", "program", "primitive", "bind", "import",
                "assert", "property", "sequence", "cover", "fork", "join", "force", "release",
                "tran", "tri", "generate", "genvar", "function", "task"
            ]
            unsupportedConstructs.append(contentsOf: tokens.map(\.text).filter { unsupportedKeywords.contains($0) })
            unsupportedConstructs.append(contentsOf: unsupportedDirectives)

            while !isAtEnd {
                if match("module") {
                    modules.append(try parseModule())
                } else {
                    advance()
                }
            }

            guard !modules.isEmpty else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: path,
                    reason: "No module declaration was found."
                )
            }

            let selectedTop = topModuleName.isEmpty ? modules[0].name : topModuleName
            let resolvedSourceFiles = sourceFiles.isEmpty ? [LogicSourceFile(
                path: path,
                sha256: XcircuiteHasher().sha256(data: data),
                byteCount: Int64(data.count)
            )] : sourceFiles
            let design = RTLDesign(
                topModuleName: selectedTop,
                modules: modules,
                sourceFiles: resolvedSourceFiles
            )
            return RTLVerificationParsedDesign(
                design: design,
                sourcePaths: resolvedSourceFiles.map(\.path),
                constructCount: tokens.count,
                unsupportedConstructs: unsupportedConstructs,
                sourceArtifacts: resolvedSourceFiles.enumerated().map { index, file in
                    RTLVerificationSourceArtifact(
                        path: file.path,
                        sha256: file.sha256,
                        byteCount: file.byteCount,
                        order: index
                    )
                }
            )
        }

        mutating func parseModule() throws -> RTLModule {
            guard let nameToken = consumeIdentifier() else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: path,
                    reason: "A module name is required."
                )
            }
            let name = nameToken.text
            if check("#") {
                advance()
                if check("(") {
                    skipBalanced(open: "(", close: ")")
                }
            }

            var ports: [RTLPort] = []
            if check("(") {
                ports = parsePortList()
            }
            guard match(";") else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: path,
                    reason: "Module \(name) is missing its declaration terminator."
                )
            }

            var module = RTLModule(id: "module:\(name)", name: name, ports: ports)
            while !isAtEnd, !check("endmodule") {
                switch currentText {
                case "input", "output", "inout":
                    parseDeclaration(into: &module, isPort: true)
                case "wire", "logic", "reg", "integer":
                    parseDeclaration(into: &module, isPort: false)
                case "assign":
                    module.assignments.append(try parseAssignment(idPrefix: "assign"))
                case "always", "always_ff", "always_comb", "always_latch":
                    let process = try parseProcess()
                    module.processes.append(process)
                    if process.kind == .sequential {
                        for assignment in processAssignments(process.statements) {
                            if let target = expressionName(assignment.target), let signalIndex = module.signals.firstIndex(where: { $0.name == target }) {
                                module.signals[signalIndex].storage = .register
                            }
                        }
                    }
                case "parameter", "localparam":
                    unsupportedConstructs.append(currentText)
                    skipToTerminator()
                case "endmodule":
                    break
                default:
                    if isLikelyInstance {
                        module.instances.append(parseInstance())
                    } else {
                        unsupportedConstructs.append(currentText)
                        skipToTerminator()
                    }
                }
            }

            guard match("endmodule") else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: path,
                    reason: "Module \(name) is missing endmodule."
                )
            }
            return module
        }

        mutating func parsePortList() -> [RTLPort] {
            _ = match("(")
            var ports: [RTLPort] = []
            var direction: LogicDirection = .internalSignal
            var dataType: LogicDataType = .logic
            var range: LogicRange?
            var isSigned = false

            while !isAtEnd, !check(")") {
                if let nextDirection = logicDirection(currentText) {
                    direction = nextDirection
                    advance()
                    continue
                }
                if let nextType = logicDataType(currentText) {
                    dataType = nextType
                    advance()
                    continue
                }
                if currentText == "signed" {
                    isSigned = true
                    advance()
                    continue
                }
                if check("[") {
                    range = parseRange()
                    continue
                }
                if let token = consumeIdentifier() {
                    ports.append(RTLPort(
                        id: "port:\(token.text)",
                        name: token.text,
                        direction: direction,
                        dataType: dataType,
                        range: range,
                        isSigned: isSigned,
                        source: sourceSpan(token)
                    ))
                    if check(",") {
                        advance()
                    }
                    continue
                }
                advance()
            }
            _ = match(")")
            return ports
        }

        mutating func parseDeclaration(into module: inout RTLModule, isPort: Bool) {
            let declarationToken = advance()
            let direction = logicDirection(declarationToken.text)
            var dataType = logicDataType(declarationToken.text) ?? .logic
            var range: LogicRange?
            var isSigned = false

            if let nextType = logicDataType(currentText), direction != nil {
                dataType = nextType
                advance()
            }
            if currentText == "signed" {
                isSigned = true
                advance()
            }
            if check("[") {
                range = parseRange()
            }

            while !isAtEnd, !check(";") {
                guard let nameToken = consumeIdentifier() else {
                    advance()
                    continue
                }
                if isPort || direction != nil {
                    let resolvedDirection = direction ?? .internalSignal
                    let port = RTLPort(
                        id: "port:\(nameToken.text)",
                        name: nameToken.text,
                        direction: resolvedDirection,
                        dataType: dataType,
                        range: range,
                        isSigned: isSigned,
                        source: sourceSpan(nameToken)
                    )
                    if let existingIndex = module.ports.firstIndex(where: { $0.name == nameToken.text }) {
                        module.ports[existingIndex] = port
                    } else {
                        module.ports.append(port)
                    }
                } else {
                    module.signals.append(RTLSignal(
                        id: "signal:\(nameToken.text)",
                        name: nameToken.text,
                        dataType: dataType,
                        storage: dataType == .wire ? .net : .combinational,
                        range: range,
                        isSigned: isSigned,
                        source: sourceSpan(nameToken)
                    ))
                }
                if check(",") {
                    advance()
                } else if !check(";") {
                    skipToTerminator()
                    break
                }
            }
            _ = match(";")
        }

        mutating func parseRange() -> LogicRange? {
            guard match("[") else { return nil }
            let msb = integerValue(advance().text)
            guard match(":") else {
                skipUntil("]")
                _ = match("]")
                return nil
            }
            let lsb = integerValue(advance().text)
            _ = match("]")
            return LogicRange(msb: msb, lsb: lsb)
        }

        mutating func parseAssignment(idPrefix: String) throws -> RTLAssignment {
            let start = current
            advance()
            let target = parseExpression(stop: ["="]).expression
            guard match("=") else {
                throw RTLVerificationExecutionError.parserFailed(
                    path: path,
                    reason: "Assignment is missing '='."
                )
            }
            let value = parseExpression(stop: [";"]).expression
            _ = match(";")
            return RTLAssignment(
                id: "\(idPrefix):\(start.line):\(start.column)",
                target: target,
                value: value,
                source: sourceSpan(start)
            )
        }

        mutating func parseProcess() throws -> RTLProcess {
            let keyword = advance()
            let kind: RTLProcessKind = keyword.text == "always_comb" ? .combinational : (keyword.text == "always_latch" ? .combinational : .generic)
            var sensitivity: [String] = []
            var resolvedKind = kind
            if match("@") {
                if match("(") {
                    var depth = 1
                    while !isAtEnd, depth > 0 {
                        if check("(") { depth += 1 }
                        if check(")") {
                            depth -= 1
                            if depth == 0 {
                                advance()
                                break
                            }
                        }
                        if currentText != "posedge", currentText != "negedge", currentText != "or", currentText != "and", currentText != "iff", currentText != "*", isIdentifier(currentText) {
                            sensitivity.append(currentText)
                        }
                        advance()
                    }
                } else if match("*") {
                    sensitivity = []
                }
                if keyword.text == "always" {
                    resolvedKind = sensitivity.contains { isClockEventName($0) } ? .sequential : .combinational
                } else if keyword.text == "always_ff" {
                    resolvedKind = .sequential
                }
            } else if keyword.text == "always_ff" {
                resolvedKind = .sequential
            }

            let statements: [RTLStatement]
            if check("begin") {
                statements = parseBlock()
            } else {
                statements = [try parseStatement()]
            }
            return RTLProcess(
                id: "process:\(keyword.line):\(keyword.column)",
                kind: resolvedKind,
                sensitivity: Array(Set(sensitivity)).sorted(),
                statements: statements,
                source: sourceSpan(keyword)
            )
        }

        mutating func parseBlock() -> [RTLStatement] {
            _ = match("begin")
            var statements: [RTLStatement] = []
            while !isAtEnd, !check("end"), !check("endmodule") {
                do {
                    statements.append(try parseStatement())
                } catch {
                    unsupportedConstructs.append("statement")
                    skipToTerminator()
                }
            }
            _ = match("end")
            return statements
        }

        mutating func parseStatement() throws -> RTLStatement {
            if check("begin") {
                return .block(parseBlock())
            }
            if match("if") {
                if match("(") {
                    let condition = parseExpression(stop: [")"]).expression
                    _ = match(")")
                    let ifTrue = [try parseStatement()]
                    let ifFalse: [RTLStatement]
                    if match("else") {
                        ifFalse = [try parseStatement()]
                    } else {
                        ifFalse = []
                    }
                    return .conditional(condition: condition, ifTrue: ifTrue, ifFalse: ifFalse)
                }
            }
            if match("case") {
                unsupportedConstructs.append("case")
                skipBalanced(open: "(", close: ")")
                skipUntil("endcase")
                _ = match("endcase")
                return .null
            }
            if check(";") {
                advance()
                return .null
            }
            let start = current
            let target = parseExpression(stop: ["=", "<=", ";"]).expression
            let nonBlocking = match("<=")
            if !nonBlocking {
                guard match("=") else {
                    skipToTerminator()
                    return .null
                }
            }
            let value = parseExpression(stop: [";"]).expression
            _ = match(";")
            return .assignment(RTLAssignment(
                id: "process:\(start.line):\(start.column)",
                target: target,
                value: value,
                nonBlocking: nonBlocking,
                source: sourceSpan(start)
            ))
        }

        mutating func parseInstance() -> RTLInstance {
            let moduleToken = advance()
            let instanceToken = consumeIdentifier() ?? moduleToken
            var connections: [RTLPortConnection] = []
            if check("#") {
                advance()
                if check("(") { skipBalanced(open: "(", close: ")") }
            }
            if match("(") {
                while !isAtEnd, !check(")") {
                    if match(".") {
                        let portName = consumeIdentifier()?.text ?? "unknown"
                        _ = match("(")
                        let expression = parseExpression(stop: [")", ","]).expression
                        _ = match(")")
                        connections.append(RTLPortConnection(portName: portName, expression: expression))
                    } else {
                        let expression = parseExpression(stop: [",", ")"]).expression
                        connections.append(RTLPortConnection(portName: "\(connections.count)", expression: expression))
                    }
                    _ = match(",")
                }
                _ = match(")")
            }
            _ = match(";")
            return RTLInstance(
                id: "instance:\(instanceToken.text)",
                moduleName: moduleToken.text,
                instanceName: instanceToken.text,
                connections: connections
            )
        }

        mutating func parseExpression(stop: Set<String>, minimumPrecedence: Int = 0) -> (expression: RTLExpression, consumed: Bool) {
            var left = parsePrimary(stop: stop)
            while !isAtEnd, !stop.contains(currentText) {
                let operatorText = currentText
                let precedence = operatorPrecedence(operatorText)
                guard precedence >= minimumPrecedence else { break }
                advance()
                if operatorText == "?" {
                    let ifTrue = parseExpression(stop: [":"], minimumPrecedence: 0).expression
                    _ = match(":")
                    let ifFalse = parseExpression(stop: stop, minimumPrecedence: 0).expression
                    left = .ternary(condition: left, ifTrue: ifTrue, ifFalse: ifFalse)
                    continue
                }
                let right = parseExpression(stop: stop, minimumPrecedence: precedence + 1).expression
                left = .binary(operator: operatorText, left: left, right: right)
            }
            return (left, true)
        }

        mutating func parsePrimary(stop: Set<String>) -> RTLExpression {
            guard !isAtEnd, !stop.contains(currentText) else {
                return .string("")
            }
            if match("(") {
                let value = parseExpression(stop: [")"]).expression
                _ = match(")")
                return value
            }
            if match("{") {
                var values: [RTLExpression] = []
                while !isAtEnd, !check("}") {
                    values.append(parseExpression(stop: [",", "}"]).expression)
                    _ = match(",")
                }
                _ = match("}")
                return .concatenate(values)
            }
            if ["!", "~", "+", "-"].contains(currentText) {
                let operatorText = advance().text
                return .unary(operator: operatorText, operand: parsePrimary(stop: stop))
            }
            let token = advance()
            var result: RTLExpression
            if token.text.hasPrefix("\"") {
                result = .string(token.text)
            } else if token.text.first?.isNumber == true || token.text.first == "'" {
                result = .integer(value: Int64(integerValue(token.text)), width: literalWidth(token.text), isSigned: false)
            } else {
                result = .identifier(token.text)
            }
            if match("[") {
                let first = parseExpression(stop: [":", "]"]).expression
                if match(":") {
                    let second = parseExpression(stop: ["]"]).expression
                    _ = match("]")
                    result = .partSelect(value: result, msb: first, lsb: second)
                } else {
                    _ = match("]")
                    result = .index(value: result, index: first)
                }
            }
            return result
        }

        func processAssignments(_ statements: [RTLStatement]) -> [RTLAssignment] {
            statements.flatMap { statement in
                switch statement {
                case .assignment(let assignment):
                    return [assignment]
                case .block(let children):
                    return processAssignments(children)
                case .conditional(_, let ifTrue, let ifFalse):
                    return processAssignments(ifTrue) + processAssignments(ifFalse)
                case .caseStatement(_, let items, let defaults):
                    return items.flatMap { processAssignments($0.statements) } + processAssignments(defaults)
                case .typedCaseStatement(_, _, let items, let defaults):
                    return items.flatMap { processAssignments($0.statements) } + processAssignments(defaults)
                case .null:
                    return []
                }
            }
        }

        func expressionName(_ expression: RTLExpression) -> String? {
            switch expression {
            case .identifier(let name): return name
            case .index(let value, _), .partSelect(let value, _, _): return expressionName(value)
            default: return nil
            }
        }

        var isAtEnd: Bool { index >= tokens.count }
        var current: Token { isAtEnd ? Token(text: "", line: 0, column: 0) : tokens[index] }
        var currentText: String { current.text }

        @discardableResult
        mutating func advance() -> Token {
            let token = current
            if !isAtEnd { index += 1 }
            return token
        }

        mutating func match(_ value: String) -> Bool {
            guard currentText == value else { return false }
            advance()
            return true
        }

        func check(_ value: String) -> Bool { currentText == value }

        mutating func consumeIdentifier() -> Token? {
            guard isIdentifier(currentText) else { return nil }
            return advance()
        }

        func isIdentifier(_ value: String) -> Bool {
            guard let first = value.first else { return false }
            return first.isLetter || first == "_" || first == "$"
        }

        var isLikelyInstance: Bool {
            guard index + 2 < tokens.count else { return false }
            return isIdentifier(tokens[index].text) && isIdentifier(tokens[index + 1].text) && (tokens[index + 2].text == "(" || tokens[index + 2].text == "#")
        }

        func logicDirection(_ value: String) -> LogicDirection? {
            switch value {
            case "input": return .input
            case "output": return .output
            case "inout": return .inOut
            default: return nil
            }
        }

        func logicDataType(_ value: String) -> LogicDataType? {
            switch value {
            case "wire": return .wire
            case "logic": return .logic
            case "reg": return .reg
            case "integer": return .integer
            default: return nil
            }
        }

        func isClockEventName(_ value: String) -> Bool {
            let lowercased = value.lowercased()
            return lowercased.contains("clk") || lowercased.contains("clock")
        }

        func integerValue(_ value: String) -> Int {
            if let direct = Int(value) { return direct }
            let parts = value.split(separator: "'", maxSplits: 1)
            if parts.count == 2, let width = Int(parts[0]) {
                let digits = parts[1].drop(while: { $0 == "s" || $0 == "S" || $0 == "d" || $0 == "h" || $0 == "b" || $0 == "o" })
                if let parsed = Int(digits, radix: 16) { return parsed }
                return width
            }
            return 0
        }

        func literalWidth(_ value: String) -> Int? {
            let parts = value.split(separator: "'", maxSplits: 1)
            return parts.count == 2 ? Int(parts[0]) : nil
        }

        func operatorPrecedence(_ value: String) -> Int {
            switch value {
            case "?": return 1
            case "||": return 2
            case "&&": return 3
            case "|": return 4
            case "^": return 5
            case "&": return 6
            case "==", "!=": return 7
            case "<", ">", "<=", ">=": return 8
            case "<<", ">>": return 9
            case "+", "-": return 10
            case "*", "/", "%": return 11
            default: return -1
            }
        }

        func sourceSpan(_ token: Token) -> LogicSourceSpan {
            let mappedPath = token.line > 0 && token.line <= linePaths.count
                ? linePaths[token.line - 1]
                : path
            let location = LogicSourceLocation(
                path: mappedPath.isEmpty ? path : mappedPath,
                line: token.line,
                column: token.column,
                offset: 0
            )
            return LogicSourceSpan(start: location, end: location)
        }

        mutating func skipBalanced(open: String, close: String) {
            guard match(open) else { return }
            var depth = 1
            while !isAtEnd, depth > 0 {
                if check(open) { depth += 1 }
                if check(close) { depth -= 1 }
                advance()
            }
        }

        mutating func skipUntil(_ value: String) {
            while !isAtEnd, !check(value) { advance() }
        }

        mutating func skipToTerminator() {
            while !isAtEnd, !check(";"), !check("endmodule") {
                if check("begin") {
                    skipBalanced(open: "begin", close: "end")
                } else {
                    advance()
                }
            }
            _ = match(";")
        }
    }
}
