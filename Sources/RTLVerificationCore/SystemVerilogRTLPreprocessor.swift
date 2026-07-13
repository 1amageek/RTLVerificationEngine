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

    private struct State: Sendable {
        var defines: [String: String]
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
                        let pieces = directive.dropFirst().map(String.init)
                        if let rawKey = pieces.first {
                            let key = rawKey.split(separator: "(", maxSplits: 1).first.map(String.init) ?? rawKey
                            if rawKey.contains("(") {
                                state.unsupported.insert("define_function:\(key)")
                            } else {
                                state.defines[key] = pieces.dropFirst().joined(separator: " ")
                            }
                        } else {
                            state.unsupported.insert("define")
                        }
                    }
                    append("", path: path, state: &state)
                case "undef":
                    if state.isActive, let key = directive.dropFirst().first {
                        state.defines.removeValue(forKey: String(key))
                    }
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
                    guard let key = directive.dropFirst().first else {
                        throw RTLVerificationExecutionError.parserFailed(
                            path: path,
                            reason: "Preprocessor directive `elsif` requires a macro name."
                        )
                    }
                    let condition = state.defines[String(key)] != nil
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
            var expanded = line
            for key in state.defines.keys.sorted() {
                expanded = expanded.replacingOccurrences(of: "`\(key)", with: state.defines[key] ?? "")
            }
            append(expanded, path: path, state: &state)
        }
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
