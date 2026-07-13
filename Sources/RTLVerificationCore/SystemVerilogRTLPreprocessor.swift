import Foundation

public struct SystemVerilogRTLPreprocessor: Sendable {
    public init() {}

    public func preprocess(
        _ source: String,
        path: String,
        options: RTLVerificationFrontendOptions,
        includeSources: [String: String] = [:]
    ) throws -> RTLVerificationPreprocessedSource {
        var state = State(defines: options.preprocessorDefines)
        try process(
            source,
            path: path,
            includeSources: includeSources,
            includeDirectories: options.includeDirectories,
            includeStack: [path],
            state: &state
        )
        guard state.frames.isEmpty else {
            throw RTLVerificationExecutionError.parserFailed(
                path: path,
                reason: "A preprocessor conditional is missing `endif`."
            )
        }
        return RTLVerificationPreprocessedSource(
            source: state.output.joined(separator: "\n"),
            unsupportedDirectives: state.unsupported.sorted(),
            linePaths: state.linePaths,
            includedPaths: state.includedPaths.sorted()
        )
    }

    private struct ConditionalFrame: Sendable {
        var parentActive: Bool
        var branchTaken: Bool
        var currentBranchActive: Bool
        var inElse: Bool

        var active: Bool {
            parentActive && currentBranchActive
        }
    }

    private struct FunctionMacro: Sendable {
        var parameters: [String]
        var body: String
    }

    private enum ConditionalExpressionError: Error {
        case invalid
    }

    private enum ConditionalExpressionToken: Sendable, Equatable {
        case identifier(String)
        case number(Int64)
        case leftParenthesis
        case rightParenthesis
        case logicalNot
        case logicalAnd
        case logicalOr
        case equal
        case notEqual
        case less
        case lessOrEqual
        case greater
        case greaterOrEqual
        case plus
        case minus
    }

    private struct ConditionalExpressionParser: Sendable {
        private var tokens: [ConditionalExpressionToken]
        private var index: Int = 0
        private let defines: [String: String]
        private let functionNames: Set<String>

        init(
            expression: String,
            defines: [String: String],
            functionNames: Set<String>
        ) throws {
            self.tokens = try Self.tokenize(expression)
            self.defines = defines
            self.functionNames = functionNames
        }

        mutating func evaluate() throws -> Bool {
            let value = try parseLogicalOr()
            guard index == tokens.count else { throw ConditionalExpressionError.invalid }
            return value != 0
        }

        private mutating func parseLogicalOr() throws -> Int64 {
            var value = try parseLogicalAnd()
            while consumeLogicalOr() {
                let right = try parseLogicalAnd()
                value = value != 0 || right != 0 ? 1 : 0
            }
            return value
        }

        private mutating func parseLogicalAnd() throws -> Int64 {
            var value = try parseEquality()
            while consumeLogicalAnd() {
                let right = try parseEquality()
                value = value != 0 && right != 0 ? 1 : 0
            }
            return value
        }

        private mutating func parseEquality() throws -> Int64 {
            var value = try parseRelational()
            while true {
                if consumeEqual() {
                    let right = try parseRelational()
                    value = value == right ? 1 : 0
                } else if consumeNotEqual() {
                    let right = try parseRelational()
                    value = value != right ? 1 : 0
                } else {
                    return value
                }
            }
        }

        private mutating func parseRelational() throws -> Int64 {
            var value = try parseUnary()
            while true {
                if consumeLessOrEqual() {
                    let right = try parseUnary()
                    value = value <= right ? 1 : 0
                } else if consumeLess() {
                    let right = try parseUnary()
                    value = value < right ? 1 : 0
                } else if consumeGreaterOrEqual() {
                    let right = try parseUnary()
                    value = value >= right ? 1 : 0
                } else if consumeGreater() {
                    let right = try parseUnary()
                    value = value > right ? 1 : 0
                } else {
                    return value
                }
            }
        }

        private mutating func parseUnary() throws -> Int64 {
            if consumeLogicalNot() {
                return try parseUnary() == 0 ? 1 : 0
            }
            if consumePlus() {
                return try parseUnary()
            }
            if consumeMinus() {
                return -(try parseUnary())
            }
            return try parsePrimary()
        }

        private mutating func parsePrimary() throws -> Int64 {
            guard index < tokens.count else { throw ConditionalExpressionError.invalid }
            switch tokens[index] {
            case .number(let value):
                index += 1
                return value
            case .identifier(let name):
                index += 1
                if name == "defined" {
                    if consumeLeftParenthesis() {
                        guard case .identifier(let macroName) = current else {
                            throw ConditionalExpressionError.invalid
                        }
                        index += 1
                        guard consumeRightParenthesis() else {
                            throw ConditionalExpressionError.invalid
                        }
                        return isDefined(macroName) ? 1 : 0
                    }
                    guard case .identifier(let macroName) = current else {
                        throw ConditionalExpressionError.invalid
                    }
                    index += 1
                    return isDefined(macroName) ? 1 : 0
                }
                return try value(of: name)
            case .leftParenthesis:
                index += 1
                let value = try parseLogicalOr()
                guard consumeRightParenthesis() else {
                    throw ConditionalExpressionError.invalid
                }
                return value
            default:
                throw ConditionalExpressionError.invalid
            }
        }

        private var current: ConditionalExpressionToken? {
            index < tokens.count ? tokens[index] : nil
        }

        private func isDefined(_ name: String) -> Bool {
            defines[name] != nil || functionNames.contains(name)
        }

        private func value(of name: String) throws -> Int64 {
            guard let rawValue = defines[name] else {
                return functionNames.contains(name) ? 1 : 0
            }
            let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty { return 1 }
            return try Self.parseInteger(normalized)
        }

        private mutating func consumeLeftParenthesis() -> Bool {
            guard case .leftParenthesis = current else { return false }
            index += 1
            return true
        }

        private mutating func consumeRightParenthesis() -> Bool {
            guard case .rightParenthesis = current else { return false }
            index += 1
            return true
        }

        private mutating func consumeLogicalNot() -> Bool {
            consume(.logicalNot)
        }

        private mutating func consumeLogicalAnd() -> Bool {
            consume(.logicalAnd)
        }

        private mutating func consumeLogicalOr() -> Bool {
            consume(.logicalOr)
        }

        private mutating func consumeEqual() -> Bool {
            consume(.equal)
        }

        private mutating func consumeNotEqual() -> Bool {
            consume(.notEqual)
        }

        private mutating func consumeLess() -> Bool {
            consume(.less)
        }

        private mutating func consumeLessOrEqual() -> Bool {
            consume(.lessOrEqual)
        }

        private mutating func consumeGreater() -> Bool {
            consume(.greater)
        }

        private mutating func consumeGreaterOrEqual() -> Bool {
            consume(.greaterOrEqual)
        }

        private mutating func consumePlus() -> Bool {
            consume(.plus)
        }

        private mutating func consumeMinus() -> Bool {
            consume(.minus)
        }

        private mutating func consume(_ expected: ConditionalExpressionToken) -> Bool {
            guard let current, current == expected else { return false }
            index += 1
            return true
        }

        private static func tokenize(_ expression: String) throws -> [ConditionalExpressionToken] {
            var tokens: [ConditionalExpressionToken] = []
            var index = expression.startIndex
            while index < expression.endIndex {
                let character = expression[index]
                if character.isWhitespace {
                    index = expression.index(after: index)
                    continue
                }
                if character == "(" {
                    tokens.append(.leftParenthesis)
                    index = expression.index(after: index)
                    continue
                }
                if character == ")" {
                    tokens.append(.rightParenthesis)
                    index = expression.index(after: index)
                    continue
                }
                if character == "!" {
                    let next = expression.index(after: index)
                    if next < expression.endIndex, expression[next] == "=" {
                        tokens.append(.notEqual)
                        index = expression.index(after: next)
                    } else {
                        tokens.append(.logicalNot)
                        index = next
                    }
                    continue
                }
                if character == "&" || character == "|" {
                    let next = expression.index(after: index)
                    guard next < expression.endIndex, expression[next] == character else {
                        throw ConditionalExpressionError.invalid
                    }
                    tokens.append(character == "&" ? .logicalAnd : .logicalOr)
                    index = expression.index(after: next)
                    continue
                }
                if character == "=" {
                    let next = expression.index(after: index)
                    guard next < expression.endIndex, expression[next] == "=" else {
                        throw ConditionalExpressionError.invalid
                    }
                    tokens.append(.equal)
                    index = expression.index(after: next)
                    continue
                }
                if character == "<" || character == ">" {
                    let next = expression.index(after: index)
                    if next < expression.endIndex, expression[next] == "=" {
                        tokens.append(character == "<" ? .lessOrEqual : .greaterOrEqual)
                        index = expression.index(after: next)
                    } else {
                        tokens.append(character == "<" ? .less : .greater)
                        index = next
                    }
                    continue
                }
                if character == "+" {
                    tokens.append(.plus)
                    index = expression.index(after: index)
                    continue
                }
                if character == "-" {
                    tokens.append(.minus)
                    index = expression.index(after: index)
                    continue
                }
                if character.isNumber || character == "'" {
                    let start = index
                    index = expression.index(after: index)
                    while index < expression.endIndex,
                          isNumberCharacter(expression[index]) {
                        index = expression.index(after: index)
                    }
                    let raw = String(expression[start..<index])
                    tokens.append(.number(try parseInteger(raw)))
                    continue
                }
                if isIdentifierStart(character) {
                    let start = index
                    index = expression.index(after: index)
                    while index < expression.endIndex,
                          isIdentifierCharacter(expression[index]) {
                        index = expression.index(after: index)
                    }
                    tokens.append(.identifier(String(expression[start..<index])))
                    continue
                }
                throw ConditionalExpressionError.invalid
            }
            return tokens
        }

        private static func parseInteger(_ raw: String) throws -> Int64 {
            let normalized = raw.replacingOccurrences(of: "_", with: "")
            if normalized == "'0" { return 0 }
            if normalized == "'1" { return 1 }
            if let quote = normalized.firstIndex(of: "'") {
                let baseAndDigits = normalized[normalized.index(after: quote)...]
                guard let base = baseAndDigits.first else { throw ConditionalExpressionError.invalid }
                let digits = baseAndDigits.dropFirst()
                let radix: Int
                switch base.lowercased() {
                case "b": radix = 2
                case "o": radix = 8
                case "d": radix = 10
                case "h": radix = 16
                default: throw ConditionalExpressionError.invalid
                }
                guard let value = Int64(digits, radix: radix) else {
                    throw ConditionalExpressionError.invalid
                }
                return value
            }
            guard let value = Int64(normalized) else { throw ConditionalExpressionError.invalid }
            return value
        }

        private static func isNumberCharacter(_ character: Character) -> Bool {
            character.isNumber || character.isLetter || character == "_" || character == "'"
        }

        private static func isIdentifierStart(_ character: Character) -> Bool {
            character == "_" || character.isLetter
        }

        private static func isIdentifierCharacter(_ character: Character) -> Bool {
            isIdentifierStart(character) || character.isNumber || character == "$"
        }
    }

    private struct State: Sendable {
        var defines: [String: String]
        var functionDefines: [String: FunctionMacro] = [:]
        var frames: [ConditionalFrame] = []
        var output: [String] = []
        var linePaths: [String] = []
        var unsupported: Set<String> = []
        var includedPaths: Set<String> = []

        init(defines: [String: String]) {
            self.defines = defines
        }

        var isActive: Bool {
            frames.allSatisfy(\.active)
        }
    }

    private func process(
        _ source: String,
        path: String,
        includeSources: [String: String],
        includeDirectories: [String],
        includeStack: [String],
        state: inout State
    ) throws {
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("`") {
                let directive = trimmed.dropFirst().split(
                    whereSeparator: { $0 == " " || $0 == "\t" }
                )
                guard let name = directive.first else {
                    append("", path: path, state: &state)
                    continue
                }
                switch name {
                case "define":
                    if state.isActive {
                        let definition = directive.dropFirst().map(String.init).joined(separator: " ")
                        if let function = parseFunctionMacro(definition) {
                            state.functionDefines[function.name] = FunctionMacro(
                                parameters: function.parameters,
                                body: function.body
                            )
                            state.defines.removeValue(forKey: function.name)
                        } else if let object = parseObjectMacro(definition) {
                            state.defines[object.name] = object.value
                            state.functionDefines.removeValue(forKey: object.name)
                        } else {
                            state.unsupported.insert("define")
                        }
                    }
                    append("", path: path, state: &state)
                case "undef":
                    if state.isActive, let key = directive.dropFirst().first {
                        state.defines.removeValue(forKey: String(key))
                        state.functionDefines.removeValue(forKey: String(key))
                    }
                    append("", path: path, state: &state)
                case "if":
                    let expression = directive.dropFirst().map(String.init).joined(separator: " ")
                    guard !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor directive `if` requires an expression."
                        )
                    }
                    let parentActive = state.isActive
                    let condition = parentActive
                        ? (evaluateConditionalExpression(expression, state: &state) ?? false)
                        : false
                    state.frames.append(ConditionalFrame(
                        parentActive: parentActive,
                        branchTaken: condition,
                        currentBranchActive: condition,
                        inElse: false
                    ))
                    append("", path: path, state: &state)
                case "ifdef", "ifndef":
                    guard let key = directive.dropFirst().first else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor directive `\(name)` requires a macro name."
                        )
                    }
                    let parentActive = state.isActive
                    let defined = state.defines[String(key)] != nil
                        || state.functionDefines[String(key)] != nil
                    state.frames.append(ConditionalFrame(
                        parentActive: parentActive,
                        branchTaken: name == "ifdef" ? defined : !defined,
                        currentBranchActive: name == "ifdef" ? defined : !defined,
                        inElse: false
                    ))
                    append("", path: path, state: &state)
                case "elsif":
                    guard let index = state.frames.indices.last else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor `elsif` has no matching conditional."
                        )
                    }
                    guard !state.frames[index].inElse else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor `elsif` cannot follow `else`."
                        )
                    }
                    let expression = directive.dropFirst().map(String.init).joined(separator: " ")
                    guard !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor directive `elsif` requires an expression."
                        )
                    }
                    let canEvaluate = state.frames[index].parentActive && !state.frames[index].branchTaken
                    let condition = canEvaluate
                        ? (evaluateConditionalExpression(expression, state: &state) ?? false)
                        : false
                    state.frames[index].currentBranchActive = !state.frames[index].branchTaken && condition
                    state.frames[index].branchTaken = state.frames[index].branchTaken || condition
                    append("", path: path, state: &state)
                case "else":
                    guard let index = state.frames.indices.last else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor `else` has no matching conditional."
                        )
                    }
                    guard !state.frames[index].inElse else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor conditional contains more than one `else`."
                        )
                    }
                    state.frames[index].inElse = true
                    state.frames[index].currentBranchActive = !state.frames[index].branchTaken
                    append("", path: path, state: &state)
                case "endif":
                    guard !state.frames.isEmpty else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor `endif` has no matching conditional."
                        )
                    }
                    state.frames.removeLast()
                    append("", path: path, state: &state)
                case "include":
                    append("", path: path, state: &state)
                    guard state.isActive else { continue }
                    guard let rawInclude = directive.dropFirst().first else {
                        state.unsupported.insert("include")
                        continue
                    }
                    let includeName = String(rawInclude).trimmingCharacters(
                        in: CharacterSet(charactersIn: "\"<>")
                    )
                    guard let resolvedPath = resolveInclude(
                        includeName,
                        includingPath: path,
                        includeSources: includeSources,
                        includeDirectories: includeDirectories
                    ) else {
                        state.unsupported.insert("include:\(includeName)")
                        continue
                    }
                    guard !includeStack.contains(resolvedPath) else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor include cycle detected at \(resolvedPath)."
                        )
                    }
                    guard let includedSource = includeSources[resolvedPath] else {
                        state.unsupported.insert("include:\(includeName)")
                        continue
                    }
                    state.includedPaths.insert(resolvedPath)
                    try process(
                        includedSource,
                        path: resolvedPath,
                        includeSources: includeSources,
                        includeDirectories: includeDirectories,
                        includeStack: includeStack + [resolvedPath],
                        state: &state
                    )
                default:
                    if state.isActive {
                        state.unsupported.insert(String(name))
                    }
                    append("", path: path, state: &state)
                }
                continue
            }

            guard state.isActive else {
                append("", path: path, state: &state)
                continue
            }
            let expanded = expandMacros(in: line, state: &state)
            append(expanded, path: path, state: &state)
        }
    }

    private func evaluateConditionalExpression(
        _ expression: String,
        state: inout State
    ) -> Bool? {
        let expanded = expandMacros(in: expression, state: &state)
        do {
            var parser = try ConditionalExpressionParser(
                expression: expanded,
                defines: state.defines,
                functionNames: Set(state.functionDefines.keys)
            )
            return try parser.evaluate()
        } catch {
            let normalized = expression.trimmingCharacters(in: .whitespacesAndNewlines)
            state.unsupported.insert("conditional_expression:\(normalized)")
            return nil
        }
    }

    private func parseFunctionMacro(
        _ definition: String
    ) -> (name: String, parameters: [String], body: String)? {
        guard let open = definition.firstIndex(of: "(") else { return nil }
        let name = definition[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
        guard isIdentifier(String(name)), let close = matchingParenthesis(in: definition, opening: open) else {
            return nil
        }
        let parametersText = String(definition[definition.index(after: open)..<close])
        let parameters: [String]
        if parametersText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parameters = []
        } else {
            parameters = parametersText.split(separator: ",", omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parameters.allSatisfy(isIdentifier), Set(parameters).count == parameters.count else {
                return nil
            }
        }
        let body = String(definition[definition.index(after: close)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (String(name), parameters, body)
    }

    private func parseObjectMacro(
        _ definition: String
    ) -> (name: String, value: String)? {
        let pieces = definition.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == " " || $0 == "\t" }
        )
        guard let name = pieces.first, isIdentifier(String(name)) else { return nil }
        let value = pieces.dropFirst().first.map(String.init) ?? ""
        return (String(name), value)
    }

    private func expandMacros(
        in line: String,
        state: inout State,
        activeFunctions: Set<String> = [],
        depth: Int = 0
    ) -> String {
        guard depth < 64 else {
            state.unsupported.insert("macro_expansion_depth")
            return line
        }

        var expanded = line
        let objectMacroNames = state.defines.keys.sorted()
        for key in objectMacroNames {
            guard let value = state.defines[key] else { continue }
            expanded = replaceObjectMacro(
                named: key,
                value: value,
                in: expanded,
                state: &state,
                activeFunctions: activeFunctions,
                depth: depth
            )
        }
        let functionMacroNames = state.functionDefines.keys.sorted()
        for key in functionMacroNames where !activeFunctions.contains(key) {
            expanded = expandFunctionMacro(
                named: key,
                in: expanded,
                state: &state,
                activeFunctions: activeFunctions,
                depth: depth
            )
        }
        for key in activeFunctions where expanded.contains("`\(key)") {
            state.unsupported.insert("define_function_recursion:\(key)")
        }
        return expanded
    }

    private func replaceObjectMacro(
        named name: String,
        value: String,
        in text: String,
        state: inout State,
        activeFunctions: Set<String>,
        depth: Int
    ) -> String {
        var result = ""
        var cursor = text.startIndex
        let token = "`\(name)"
        while let range = text.range(of: token, range: cursor..<text.endIndex) {
            result.append(contentsOf: text[cursor..<range.lowerBound])
            let after = range.upperBound
            if after < text.endIndex, text[after] == "(" {
                result.append(contentsOf: text[range.lowerBound..<after])
                cursor = after
                continue
            }
            result.append(expandMacros(
                in: value,
                state: &state,
                activeFunctions: activeFunctions,
                depth: depth + 1
            ))
            cursor = after
        }
        result.append(contentsOf: text[cursor...])
        return result
    }

    private func expandFunctionMacro(
        named name: String,
        in text: String,
        state: inout State,
        activeFunctions: Set<String>,
        depth: Int
    ) -> String {
        guard let macro = state.functionDefines[name] else { return text }
        let token = "`\(name)"
        var result = ""
        var cursor = text.startIndex
        while let range = text.range(of: token, range: cursor..<text.endIndex) {
            result.append(contentsOf: text[cursor..<range.lowerBound])
            let afterName = range.upperBound
            guard afterName < text.endIndex, text[afterName] == "(" else {
                result.append(contentsOf: text[range.lowerBound..<afterName])
                cursor = afterName
                continue
            }
            guard let close = matchingParenthesis(in: text, opening: afterName) else {
                state.unsupported.insert("define_function_invocation:\(name)")
                result.append(contentsOf: text[range.lowerBound...])
                return result
            }
            let argumentText = String(text[text.index(after: afterName)..<close])
            guard let arguments = splitArguments(argumentText), arguments.count == macro.parameters.count else {
                state.unsupported.insert("define_function_invocation:\(name)")
                result.append(contentsOf: text[range.lowerBound...close])
                cursor = text.index(after: close)
                continue
            }
            var replacement = macro.body
            for (parameter, argument) in zip(macro.parameters, arguments) {
                let expandedArgument = expandMacros(
                    in: argument,
                    state: &state,
                    activeFunctions: activeFunctions,
                    depth: depth + 1
                )
                replacement = replaceIdentifier(parameter, with: expandedArgument, in: replacement)
            }
            replacement = expandMacros(
                in: replacement,
                state: &state,
                activeFunctions: activeFunctions.union([name]),
                depth: depth + 1
            )
            result.append(replacement)
            cursor = text.index(after: close)
        }
        result.append(contentsOf: text[cursor...])
        return result
    }

    private func replaceIdentifier(_ name: String, with value: String, in text: String) -> String {
        guard !name.isEmpty else { return text }
        var result = ""
        var cursor = text.startIndex
        while let range = text.range(of: name, range: cursor..<text.endIndex) {
            let beforeIsIdentifier = range.lowerBound > text.startIndex
                && isIdentifierCharacter(text[text.index(before: range.lowerBound)])
            let afterIsIdentifier = range.upperBound < text.endIndex
                && isIdentifierCharacter(text[range.upperBound])
            result.append(contentsOf: text[cursor..<range.lowerBound])
            if !beforeIsIdentifier && !afterIsIdentifier {
                result.append(contentsOf: value)
            } else {
                result.append(contentsOf: text[range])
            }
            cursor = range.upperBound
        }
        result.append(contentsOf: text[cursor...])
        return result
    }

    private func splitArguments(_ text: String) -> [String]? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        var result: [String] = []
        var start = text.startIndex
        var parenthesisDepth = 0
        var bracketDepth = 0
        var braceDepth = 0
        var inString = false
        var escaped = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"": inString = true
                case "(": parenthesisDepth += 1
                case ")": parenthesisDepth -= 1
                case "[": bracketDepth += 1
                case "]": bracketDepth -= 1
                case "{": braceDepth += 1
                case "}": braceDepth -= 1
                case "," where parenthesisDepth == 0 && bracketDepth == 0 && braceDepth == 0:
                    result.append(String(text[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines))
                    start = text.index(after: index)
                default: break
                }
                if parenthesisDepth < 0 || bracketDepth < 0 || braceDepth < 0 {
                    return nil
                }
            }
            index = text.index(after: index)
        }
        guard !inString, parenthesisDepth == 0, bracketDepth == 0, braceDepth == 0 else { return nil }
        result.append(String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    private func matchingParenthesis(in text: String, opening: String.Index) -> String.Index? {
        guard opening < text.endIndex, text[opening] == "(" else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = opening
        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"": inString = true
                case "(": depth += 1
                case ")":
                    depth -= 1
                    if depth == 0 { return index }
                default: break
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private func isIdentifier(_ value: String) -> Bool {
        guard let first = value.first, first == "_" || first.isLetter else { return false }
        return value.dropFirst().allSatisfy(isIdentifierCharacter)
    }

    private func isIdentifierCharacter(_ character: Character) -> Bool {
        character == "_" || character.isLetter || character.isNumber || character == "$"
    }

    private func append(_ line: String, path: String, state: inout State) {
        state.output.append(line)
        state.linePaths.append(path)
    }

    private func resolveInclude(
        _ includeName: String,
        includingPath: String,
        includeSources: [String: String],
        includeDirectories: [String]
    ) -> String? {
        let includingDirectory = URL(fileURLWithPath: includingPath)
            .deletingLastPathComponent()
            .path
        let candidates = [
            includeName,
            URL(fileURLWithPath: includingDirectory)
                .appendingPathComponent(includeName)
                .path
        ] + includeDirectories.map {
            URL(fileURLWithPath: $0).appendingPathComponent(includeName).path
        }
        for candidate in candidates {
            if let matchingPath = includeSources.keys.first(where: {
                normalize($0) == normalize(candidate)
            }) {
                return matchingPath
            }
        }
        let basename = URL(fileURLWithPath: includeName).lastPathComponent
        return includeSources.keys.first {
            URL(fileURLWithPath: $0).lastPathComponent == basename
        }
    }

    private func normalize(_ path: String) -> String {
        var components: [String] = []
        for component in path.split(separator: "/").map(String.init) {
            if component == "." || component.isEmpty { continue }
            if component == ".." {
                _ = components.popLast()
            } else {
                components.append(component)
            }
        }
        return components.joined(separator: "/")
    }
}
