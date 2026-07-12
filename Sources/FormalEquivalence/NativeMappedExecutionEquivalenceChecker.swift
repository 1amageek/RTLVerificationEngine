import Foundation
import LogicEngineCore
import LogicIR
import LogicLowering
import RTLVerificationCore
import XcircuitePackage

public struct NativeMappedExecutionEquivalenceChecker: FormalEquivalenceChecking {
    public var environment: RTLVerificationEnvironment

    public init(environment: RTLVerificationEnvironment) {
        self.environment = environment
    }

    public init(
        reader: any RTLArtifactReading,
        writer: any RTLArtifactWriting = InMemoryRTLArtifactStore()
    ) {
        self.environment = RTLVerificationEnvironment(reader: reader, writer: writer)
    }

    public func execute(
        _ request: RTLVerificationRequest
    ) async throws -> XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
        let startedAt = Date()
        guard request.analysis == .formalEquivalence else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("Mapped execution equivalence requires analysis=formalEquivalence.")
            )
        }
        guard let mappedReference = request.referenceDesign else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("Mapped execution equivalence requires a mapped design artifact.")
            )
        }
        guard request.proofView == .rtlToMappedExecutionStructural else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("The mapped execution checker received an incompatible proof view.")
            )
        }
        guard request.assumptions.isEmpty else {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidRequest("Native mapped execution structural formal does not interpret declared assumptions.")
            )
        }

        do {
            let sourceData = try environment.reader.read(request.design.artifact)
            try validateArtifactIntegrity(sourceData, reference: request.design.artifact)
            let sourceDocument = try loadSourceDocument(sourceData, request: request)

            let mappedData = try environment.reader.read(mappedReference.artifact)
            try validateArtifactIntegrity(mappedData, reference: mappedReference.artifact)
            let mappedDocument = try loadMappedDocument(mappedData, request: request)

            let comparison = compare(sourceDocument, mappedDocument)
            let sourceArtifact = sourceArtifactReference(request.design.artifact, data: sourceData, order: 0)
            let mappedArtifact = sourceArtifactReference(mappedReference.artifact, data: mappedData, order: 1)
            let coverage = RTLVerificationCoverage(
                totalConstructs: sourceDocument.nodes.count + mappedDocument.nodes.count,
                analyzedConstructs: sourceDocument.nodes.count + mappedDocument.nodes.count,
                proofScope: request.proofView.rawValue,
                limitations: [
                    "The native mapped execution scope proves canonical LogicEngine execution-graph equivalence.",
                    "This backend does not prove temporal sequential behavior or analog behavior.",
                    "A qualified execution-model backend is required for trace-level mapped equivalence."
                ],
                sourceArtifacts: [sourceArtifact, mappedArtifact]
            )
            let isProved = comparison.mismatches.isEmpty
            let findings: [RTLVerificationFinding]
            if isProved {
                findings = [
                    RTLVerificationFinding(
                        severity: .info,
                        code: "FORMAL_MAPPED_EXECUTION_PROVED",
                        message: "The source and mapped designs are canonically equivalent in the declared mapped execution structural scope.",
                        entity: request.design.topDesignName,
                        suggestedActions: ["retain_proof_artifact", "record_synthesis_acceptance"]
                    ),
                    RTLVerificationFinding(
                        severity: .info,
                        code: "FORMAL_MAPPED_EQUIVALENCE_PROVED",
                        message: "The mapped execution equivalence proof completed for the declared structural scope.",
                        entity: request.design.topDesignName
                    )
                ]
            } else {
                findings = [
                    RTLVerificationFinding(
                        severity: .error,
                        code: "FORMAL_MAPPED_EXECUTION_UNPROVEN",
                        message: "The source and mapped designs differ in the declared mapped execution structural scope.",
                        entity: request.design.topDesignName,
                        suggestedActions: ["inspect_counterexample", "repair_synthesis_or_mapping", "rerun_equivalence"]
                    )
                ]
            }
            let counterexampleData: Data?
            let counterexampleArtifactID: String?
            if isProved {
                counterexampleData = nil
                counterexampleArtifactID = nil
            } else {
                let counterexample = RTLFormalCounterexample(
                    runID: request.runID,
                    topModuleName: request.design.topDesignName,
                    mismatches: comparison.mismatches,
                    affectedEntities: [request.design.topDesignName],
                    proofScope: request.proofView.rawValue
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
                counterexampleData = try encoder.encode(counterexample)
                counterexampleArtifactID = "formal-mapped-execution-counterexample"
            }

            return try await RTLVerificationExecutionSupport.finalize(
                request: request,
                environment: environment,
                startedAt: startedAt,
                requestedStatus: isProved ? .completed : .blocked,
                diagnostics: [],
                analysisResult: RTLVerificationAnalysisResult(
                    findings: findings,
                    coverage: coverage,
                    proofStatus: isProved ? "proved" : "unproven",
                    counterexampleData: counterexampleData,
                    counterexampleArtifactID: counterexampleArtifactID
                )
            )
        } catch let error as RTLVerificationExecutionError {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: error
            )
        } catch let error as LogicExecutionError {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidArtifact(error.localizedDescription)
            )
        } catch {
            return try await RTLVerificationExecutionSupport.blockedEnvelope(
                request: request,
                environment: environment,
                startedAt: startedAt,
                error: .invalidArtifact(error.localizedDescription)
            )
        }
    }

    private func loadSourceDocument(
        _ data: Data,
        request: RTLVerificationRequest
    ) throws -> LogicDesignDocument {
        do {
            _ = try JSONDecoder().decode(LogicDesignSnapshot.self, from: data)
            let snapshot = try LogicDesignSnapshotCodec.decode(data)
            let digest = try LogicDesignSnapshotCodec.digest(snapshot)
            guard request.design.designDigest == digest else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "source snapshot digest does not match the request design reference"
                )
            }
            let lowering = NativeLogicDesignLowering().lower(snapshot)
            guard lowering.status == .completed, let document = lowering.document else {
                let message = lowering.diagnostics.map(\.message).joined(separator: "; ")
                throw RTLVerificationExecutionError.invalidArtifact(
                    "source snapshot could not be lowered into the native execution graph: \(message)"
                )
            }
            return document
        } catch is DecodingError {
            let document: LogicDesignDocument
            do {
                document = try JSONDecoder().decode(LogicDesignDocument.self, from: data)
            } catch {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "source artifact is neither a valid LogicDesignSnapshot nor LogicDesignDocument: \(error.localizedDescription)"
                )
            }
            try document.validate()
            guard document.topDesignName == request.design.topDesignName else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "source design top \(document.topDesignName) does not match request top \(request.design.topDesignName)"
                )
            }
            let digest = XcircuiteHasher().sha256(data: data)
            guard request.design.designDigest == digest else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "source design document digest does not match the request design reference"
                )
            }
            return document
        } catch let error as RTLVerificationExecutionError {
            throw error
        } catch {
            throw RTLVerificationExecutionError.invalidArtifact(error.localizedDescription)
        }
    }

    private func loadMappedDocument(
        _ data: Data,
        request: RTLVerificationRequest
    ) throws -> LogicDesignDocument {
        do {
            let document = try JSONDecoder().decode(LogicDesignDocument.self, from: data)
            try document.validate()
            guard document.topDesignName == request.design.topDesignName else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "mapped design top \(document.topDesignName) does not match request top \(request.design.topDesignName)"
                )
            }
            return document
        } catch let error as RTLVerificationExecutionError {
            throw error
        } catch let error as LogicExecutionError {
            throw error
        } catch {
            throw RTLVerificationExecutionError.invalidArtifact(
                "mapped artifact is not a valid LogicDesignDocument: \(error.localizedDescription)"
            )
        }
    }

    private func validateArtifactIntegrity(
        _ data: Data,
        reference: XcircuiteFileReference
    ) throws {
        let hasher = XcircuiteHasher()
        if let expectedSHA256 = reference.sha256 {
            let actualSHA256 = hasher.sha256(data: data)
            guard expectedSHA256 == actualSHA256 else {
                throw RTLVerificationExecutionError.artifactReadFailed(
                    path: reference.path,
                    reason: "SHA-256 digest does not match the artifact reference."
                )
            }
        }
        if let expectedByteCount = reference.byteCount {
            guard expectedByteCount == Int64(data.count) else {
                throw RTLVerificationExecutionError.artifactReadFailed(
                    path: reference.path,
                    reason: "Byte count does not match the artifact reference."
                )
            }
        }
    }

    private func sourceArtifactReference(
        _ reference: XcircuiteFileReference,
        data: Data,
        order: Int
    ) -> RTLVerificationSourceArtifact {
        RTLVerificationSourceArtifact(
            path: reference.path,
            sha256: XcircuiteHasher().sha256(data: data),
            byteCount: Int64(data.count),
            order: order
        )
    }

    private func compare(
        _ source: LogicDesignDocument,
        _ mapped: LogicDesignDocument
    ) -> Comparison {
        let sourceCanonical = CanonicalDocument(document: source)
        let mappedCanonical = CanonicalDocument(document: mapped)
        guard sourceCanonical == mappedCanonical else {
            return Comparison(
                mismatches: [
                    "Canonical mapped execution graph differs for top module (source.topDesignName)."
                ]
            )
        }
        return Comparison(mismatches: [])
    }
}

private struct Comparison: Sendable, Hashable {
    let mismatches: [String]
}

private struct CanonicalDocument: Sendable, Hashable {
    let topDesignName: String
    let ports: [CanonicalPort]
    let signals: [CanonicalSignal]
    let nodes: [CanonicalNode]

    init(document: LogicDesignDocument) {
        topDesignName = document.topDesignName
        ports = document.ports
            .map(CanonicalPort.init)
            .sorted { $0.name < $1.name }
        signals = document.signals
            .map(CanonicalSignal.init)
            .sorted { $0.name < $1.name }
        nodes = document.nodes
            .map(CanonicalNode.init)
            .sorted { lhs, rhs in
                lhs.sortKey < rhs.sortKey
            }
    }
}

private struct CanonicalPort: Sendable, Hashable {
    let name: String
    let direction: LogicPortDirection
    let width: Int

    init(_ port: LogicPort) {
        name = port.name
        direction = port.direction
        width = port.width
    }
}

private struct CanonicalSignal: Sendable, Hashable {
    let name: String
    let width: Int
    let isSigned: Bool

    init(_ signal: LogicSignal) {
        name = signal.name
        width = signal.width
        isSigned = signal.isSigned
    }
}

private struct CanonicalNode: Sendable, Hashable {
    let kind: LogicNodeKind
    let inputs: [String]
    let outputs: [String]
    let parameters: [String: String]

    var sortKey: String {
        let parameterKey = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(kind.rawValue)|\(inputs.joined(separator: ","))|\(outputs.joined(separator: ","))|\(parameterKey)"
    }

    init(_ node: LogicNode) {
        kind = node.kind
        inputs = node.inputs
        outputs = node.outputs
        parameters = node.parameters.filter { $0.key != "mappedCell" }
    }
}
