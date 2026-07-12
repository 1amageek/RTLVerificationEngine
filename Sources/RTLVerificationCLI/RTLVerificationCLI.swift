import Darwin
import Foundation
import LogicIR
import RTLVerificationCore
import RTLVerificationEngine
import TimingCore
import XcircuitePackage

@main
struct RTLVerificationCLI {
    static func main() async {
        do {
            let result = try await run(arguments: Array(CommandLine.arguments.dropFirst()))
            let data = try encode(result)
            print(String(decoding: data, as: UTF8.self))
            if result.status != .completed {
                exit(1)
            }
        } catch {
            let output: [String: String] = [
                "code": "RTL_CLI_FAILED",
                "message": error.localizedDescription
            ]
            do {
                let data = try encode(output)
                FileHandle.standardError.write(data)
                FileHandle.standardError.write(Data("\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("{\"code\":\"RTL_CLI_FAILED\"}\n".utf8))
            }
            exit(2)
        }
    }

    private static func run(
        arguments: [String]
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
        let options = try Options(arguments: arguments)
        if options.help {
            return XcircuiteEngineResultEnvelope(
                schemaVersion: RTLVerificationRequest.currentSchemaVersion,
                runID: "help",
                status: .completed,
                diagnostics: [XcircuiteEngineDiagnostic(
                    severity: .info,
                    code: "RTL_CLI_HELP",
                message: "Use --analysis, --project-root, repeated --rtl/--reference, --top, --run-id, optional --constraint, frontend options, proof view, waivers, assumptions and --qualification-input.",
                suggestedActions: ["run_rtl_verify"]
                )],
                metadata: XcircuiteEngineExecutionMetadata(
                    engineID: "rtl.cli",
                    implementationID: RTLVerificationExecutionSupport.implementationID,
                    implementationVersion: RTLVerificationExecutionSupport.implementationVersion,
                    startedAt: Date(),
                    completedAt: Date()
                ),
                payload: RTLVerificationPayload(findingCount: 0)
            )
        }

        let packageStore = XcircuitePackageStore()
        let inputPaths = try options.inputPaths(projectRoot: options.projectRoot)
        let rtlReferences = try inputPaths.enumerated().map { index, path in
            try packageStore.fileReference(
                forProjectRelativePath: path,
                artifactID: index == 0 ? "rtl-input" : "rtl-input-\(index)",
                kind: .rtl,
                format: format(for: path),
                inProjectAt: options.projectRoot
            )
        }
        guard let rtlReference = rtlReferences.first else {
            throw RTLVerificationExecutionError.invalidRequest("At least one --rtl input is required.")
        }
        let design = LogicDesignReference(
            artifact: rtlReference,
            topDesignName: options.topModule,
            designDigest: rtlReference.sha256 ?? ""
        )
        let referenceReferences = try options.referencePaths.enumerated().map { index, referencePath in
            try packageStore.fileReference(
                forProjectRelativePath: referencePath,
                artifactID: index == 0 ? "rtl-reference" : "rtl-reference-\(index)",
                kind: .rtl,
                format: format(for: referencePath),
                inProjectAt: options.projectRoot
            )
        }
        let referenceDesign: LogicDesignReference?
        if let reference = referenceReferences.first {
            referenceDesign = LogicDesignReference(
                artifact: reference,
                topDesignName: options.topModule,
                designDigest: reference.sha256 ?? ""
            )
        } else {
            referenceDesign = nil
        }
        let referenceInputs = Array(referenceReferences.dropFirst())
        let constraintReference: TimingConstraintReference?
        if let constraintPath = options.constraintPath {
            let reference = try packageStore.fileReference(
                forProjectRelativePath: constraintPath,
                artifactID: "rtl-constraints",
                kind: .constraint,
                format: .sdc,
                inProjectAt: options.projectRoot
            )
            constraintReference = TimingConstraintReference(artifact: reference, modeIDs: options.constraintModes)
        } else {
            constraintReference = nil
        }
        let waivers = try options.waiversPath.map {
            try packageStore.readJSON([RTLVerificationWaiver].self, named: $0, forProjectAt: options.projectRoot)
        } ?? []
        let assumptions = try options.assumptionsPath.map {
            try packageStore.readJSON([RTLVerificationAssumption].self, named: $0, forProjectAt: options.projectRoot)
        } ?? []
        let qualificationInput = try options.qualificationInputPath.map {
            try packageStore.readJSON(
                RTLVerificationQualificationInput.self,
                named: $0,
                forProjectAt: options.projectRoot
            )
        }
        let request = RTLVerificationRequest(
            runID: options.runID,
            inputs: rtlReferences + (constraintReference.map { [$0.artifact] } ?? []),
            design: design,
            referenceDesign: referenceDesign,
            referenceInputs: referenceInputs,
            constraints: constraintReference,
            analysis: options.analysis,
            policy: RTLVerificationPolicy(
                requiredProof: options.requiredProof,
                maximumUnsupportedConstructs: options.maximumUnsupportedConstructs,
                allowWarnings: options.allowWarnings,
                minimumQualification: options.minimumQualification
            ),
            waivers: waivers,
            frontend: RTLVerificationFrontendOptions(
                language: options.language,
                preprocessorDefines: options.preprocessorDefines,
                includeDirectories: options.includeDirectories
            ),
            proofView: options.proofView,
            assumptions: assumptions,
            qualificationInput: qualificationInput
        )
        let environment = RTLVerificationEnvironment(
            reader: FileSystemRTLArtifactReader(projectRoot: options.projectRoot),
            writer: FileSystemRTLArtifactStore(projectRoot: options.projectRoot)
        )
        return try await RTLVerificationEngine(environment: environment).execute(request)
    }

    private static func format(for path: String) -> XcircuiteFileFormat {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "sv", "svh": return .systemVerilog
        case "v", "vh": return .verilog
        case "json": return .json
        case "sdc": return .sdc
        default: return .text
        }
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private struct Options {
        var analysis: RTLVerificationAnalysis = .lint
        var projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var rtlPaths: [String] = []
        var referencePaths: [String] = []
        var constraintPath: String?
        var constraintModes: [String] = []
        var waiversPath: String?
        var assumptionsPath: String?
        var qualificationInputPath: String?
        var preprocessorDefines: [String: String] = [:]
        var includeDirectories: [String] = []
        var language = "systemVerilog"
        var proofView: RTLVerificationProofView = .rtlToRtlStructural
        var minimumQualification: RTLVerificationQualificationState = .unassessed
        var maximumUnsupportedConstructs = 0
        var allowWarnings = true
        var requiredProof = true
        var topModule = ""
        var runID = "rtl-run"
        var help = false

        init(arguments: [String]) throws {
            var index = 0
            while index < arguments.count {
                let argument = arguments[index]
                switch argument {
                case "--help", "-h":
                    help = true
                case "--analysis":
                    analysis = try parseAnalysis(next(arguments, index: &index))
                case "--project-root":
                    projectRoot = URL(fileURLWithPath: try next(arguments, index: &index), isDirectory: true)
                case "--rtl":
                    rtlPaths.append(try next(arguments, index: &index))
                case "--reference":
                    referencePaths.append(try next(arguments, index: &index))
                case "--constraint":
                    constraintPath = try next(arguments, index: &index)
                case "--constraint-mode":
                    constraintModes.append(try next(arguments, index: &index))
                case "--waivers":
                    waiversPath = try next(arguments, index: &index)
                case "--assumptions":
                    assumptionsPath = try next(arguments, index: &index)
                case "--qualification-input":
                    qualificationInputPath = try next(arguments, index: &index)
                case "--define":
                    let definition = try parseDefinition(next(arguments, index: &index))
                    preprocessorDefines[definition.name] = definition.value
                case "--include-dir":
                    includeDirectories.append(try next(arguments, index: &index))
                case "--language":
                    language = try next(arguments, index: &index)
                case "--proof-view":
                    proofView = try parseProofView(next(arguments, index: &index))
                case "--minimum-qualification":
                    minimumQualification = try parseQualification(next(arguments, index: &index))
                case "--max-unsupported":
                    maximumUnsupportedConstructs = try parseNonNegativeInt(next(arguments, index: &index))
                case "--deny-warnings":
                    allowWarnings = false
                case "--no-required-proof":
                    requiredProof = false
                case "--top":
                    topModule = try next(arguments, index: &index)
                case "--run-id":
                    runID = try next(arguments, index: &index)
                default:
                    throw RTLVerificationExecutionError.invalidRequest("Unknown CLI option \(argument).")
                }
                index += 1
            }
            if !help {
                guard !rtlPaths.isEmpty else { throw RTLVerificationExecutionError.invalidRequest("--rtl is required.") }
                guard !topModule.isEmpty else { throw RTLVerificationExecutionError.invalidRequest("--top is required.") }
            }
        }

        private func next(_ arguments: [String], index: inout Int) throws -> String {
            index += 1
            guard index < arguments.count else {
                throw RTLVerificationExecutionError.invalidRequest("Missing value for CLI option.")
            }
            return arguments[index]
        }

        private func parseAnalysis(_ value: String) throws -> RTLVerificationAnalysis {
            guard let analysis = RTLVerificationAnalysis(rawValue: value) else {
                throw RTLVerificationExecutionError.invalidRequest("Unsupported analysis \(value).")
            }
            return analysis
        }

        private func parseProofView(_ value: String) throws -> RTLVerificationProofView {
            guard let proofView = RTLVerificationProofView(rawValue: value) else {
                throw RTLVerificationExecutionError.invalidRequest("Unsupported proof view \(value).")
            }
            return proofView
        }

        private func parseQualification(_ value: String) throws -> RTLVerificationQualificationState {
            guard let state = RTLVerificationQualificationState(rawValue: value) else {
                throw RTLVerificationExecutionError.invalidRequest("Unsupported qualification state \(value).")
            }
            return state
        }

        private func parseNonNegativeInt(_ value: String) throws -> Int {
            guard let number = Int(value), number >= 0 else {
                throw RTLVerificationExecutionError.invalidRequest("Expected a non-negative integer, got \(value).")
            }
            return number
        }

        private func parseDefinition(_ value: String) throws -> (name: String, value: String) {
            let pieces = value.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let rawName = pieces.first, !rawName.isEmpty else {
                throw RTLVerificationExecutionError.invalidRequest("--define requires NAME or NAME=VALUE.")
            }
            let name = String(rawName)
            let macroValue = pieces.count == 2 ? String(pieces[1]) : "1"
            return (name: name, value: macroValue)
        }

        func inputPaths(projectRoot: URL) throws -> [String] {
            var paths = rtlPaths
            let rootPath = projectRoot.standardizedFileURL.path(percentEncoded: false)
            for directory in includeDirectories {
                let directoryURL = projectRoot.appending(path: directory).standardizedFileURL
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(
                    atPath: directoryURL.path(percentEncoded: false),
                    isDirectory: &isDirectory
                ), isDirectory.boolValue else {
                    throw RTLVerificationExecutionError.invalidRequest(
                        "Include directory does not exist: \(directory)."
                    )
                }
                guard let enumerator = FileManager.default.enumerator(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    throw RTLVerificationExecutionError.invalidRequest(
                        "Include directory cannot be enumerated: \(directory)."
                    )
                }
                for case let fileURL as URL in enumerator {
                    let extensionName = fileURL.pathExtension.lowercased()
                    guard extensionName == "svh" || extensionName == "vh" else { continue }
                    let filePath = fileURL.standardizedFileURL.path(percentEncoded: false)
                    guard filePath.hasPrefix(rootPath + "/") else {
                        throw RTLVerificationExecutionError.invalidRequest(
                            "Include file escapes the project root: \(filePath)."
                        )
                    }
                    let relativePath = String(filePath.dropFirst(rootPath.count + 1))
                    if !paths.contains(relativePath) {
                        paths.append(relativePath)
                    }
                }
            }
            return paths
        }
    }
}
