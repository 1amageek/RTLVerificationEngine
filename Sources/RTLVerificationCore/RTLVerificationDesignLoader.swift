import Foundation
import CircuiteFoundation
import LogicIR

public struct RTLVerificationDesignLoader: Sendable {
    public var reader: any RTLArtifactReading
    public var parser: any RTLVerificationDesignParsing

    public init(
        reader: any RTLArtifactReading,
        parser: any RTLVerificationDesignParsing = SystemVerilogRTLParser()
    ) {
        self.reader = reader
        self.parser = parser
    }

    public func load(_ request: RTLVerificationRequest) throws -> RTLVerificationParsedDesign {
        let designReference = try materialize(request.design.artifact)
        let references = uniqueReferences(
            [designReference] + request.inputs.filter { $0.locator.kind == .rtl }
        )
        let sourceInputs = try references.map { reference in
            RTLVerificationSourceInput(reference: reference, data: try reader.read(reference))
        }
        if let sourceSetParser = parser as? RTLVerificationSourceSetParsing,
           references.allSatisfy({ $0.format != .json }) {
            let parsed = try sourceSetParser.parse(
                sources: sourceInputs,
                topModuleName: request.design.topDesignName,
                options: request.frontend
            )
            try validateUniqueModules(parsed.design)
            return try normalize(parsed, request: request)
        }
        var merged: RTLVerificationParsedDesign?
        for (index, reference) in references.enumerated() {
            let data = sourceInputs[index].data
            let parsed = try parse(
                data: data,
                reference: reference,
                topModuleName: request.design.topDesignName,
                options: request.frontend
            )
            if let current = merged {
                let moduleNames = Set(current.design.modules.map(\.name))
                let duplicates = parsed.design.modules.map(\.name).filter { moduleNames.contains($0) }
                guard duplicates.isEmpty else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "RTL input files define duplicate modules: \(Array(Set(duplicates)).sorted().joined(separator: ", "))."
                    )
                }
                let design = RTLDesign(
                    topModuleName: request.design.topDesignName,
                    modules: current.design.modules + parsed.design.modules,
                    sourceFiles: current.design.sourceFiles + parsed.design.sourceFiles
                )
                merged = RTLVerificationParsedDesign(
                    design: design,
                    sourcePaths: current.sourcePaths + parsed.sourcePaths,
                    constructCount: current.constructCount + parsed.constructCount,
                    unsupportedConstructs: current.unsupportedConstructs + parsed.unsupportedConstructs,
                    sourceArtifacts: current.sourceArtifacts + parsed.sourceArtifacts.enumerated().map { index, artifact in
                        var updated = artifact
                        updated.order = current.sourceArtifacts.count + index
                        return updated
                    }
                )
            } else {
                merged = parsed
            }
        }
        guard let merged else {
            throw RTLVerificationExecutionError.invalidRequest("At least one RTL input artifact is required.")
        }
        return try normalize(merged, request: request)
    }

    private func normalize(
        _ parsed: RTLVerificationParsedDesign,
        request: RTLVerificationRequest
    ) throws -> RTLVerificationParsedDesign {
        var normalized = parsed
        try validateUniqueModules(normalized.design)
        let selectedTop = request.design.topDesignName.isEmpty
            ? normalized.design.modules.first?.name ?? ""
            : request.design.topDesignName
        if request.frontend.requireTopModule,
           !normalized.design.modules.contains(where: { $0.name == selectedTop }) {
            throw RTLVerificationExecutionError.invalidRequest(
                "Top module \(selectedTop) was not found in the RTL input set."
            )
        }
        normalized.design.topModuleName = selectedTop
        return normalized
    }

    private func validateUniqueModules(_ design: RTLDesign) throws {
        var seen: Set<String> = []
        let duplicates = design.modules.map(\.name).filter { !seen.insert($0).inserted }
        guard duplicates.isEmpty else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "RTL input files define duplicate modules: \(Array(Set(duplicates)).sorted().joined(separator: ", "))."
            )
        }
    }

    public func loadReference(_ request: RTLVerificationRequest) throws -> RTLVerificationParsedDesign {
        guard let referenceDesign = request.referenceDesign else {
            throw RTLVerificationExecutionError.invalidRequest("A reference design is required for formal equivalence.")
        }
        let referenceReference = try materialize(referenceDesign.artifact)
        let references = uniqueReferences([referenceReference] + request.referenceInputs)
        let sourceInputs = try references.map { reference in
            RTLVerificationSourceInput(reference: reference, data: try reader.read(reference))
        }
        if let sourceSetParser = parser as? RTLVerificationSourceSetParsing,
           references.allSatisfy({ $0.format != .json }) {
            let parsed = try sourceSetParser.parse(
                sources: sourceInputs,
                topModuleName: referenceDesign.topDesignName,
                options: request.frontend
            )
            try validateUniqueModules(parsed.design)
            return try normalizeReference(parsed, request: request)
        }
        var merged: RTLVerificationParsedDesign?
        for (index, reference) in references.enumerated() {
            let parsed = try parse(
                data: sourceInputs[index].data,
                reference: reference,
                topModuleName: referenceDesign.topDesignName,
                options: request.frontend
            )
            if let current = merged {
                let moduleNames = Set(current.design.modules.map(\.name))
                let duplicates = parsed.design.modules.map(\.name).filter { moduleNames.contains($0) }
                guard duplicates.isEmpty else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "Reference RTL input files define duplicate modules: \(Array(Set(duplicates)).sorted().joined(separator: ", "))."
                    )
                }
                merged = RTLVerificationParsedDesign(
                    design: RTLDesign(
                        topModuleName: referenceDesign.topDesignName,
                        modules: current.design.modules + parsed.design.modules,
                        sourceFiles: current.design.sourceFiles + parsed.design.sourceFiles
                    ),
                    sourcePaths: current.sourcePaths + parsed.sourcePaths,
                    constructCount: current.constructCount + parsed.constructCount,
                    unsupportedConstructs: current.unsupportedConstructs + parsed.unsupportedConstructs,
                    sourceArtifacts: current.sourceArtifacts + parsed.sourceArtifacts.enumerated().map { offset, artifact in
                        var updated = artifact
                        updated.order = current.sourceArtifacts.count + offset
                        return updated
                    }
                )
            } else {
                merged = parsed
            }
        }
        guard let merged else {
            throw RTLVerificationExecutionError.invalidRequest("At least one reference RTL input artifact is required.")
        }
        return try normalizeReference(merged, request: request)
    }

    private func normalizeReference(
        _ parsed: RTLVerificationParsedDesign,
        request: RTLVerificationRequest
    ) throws -> RTLVerificationParsedDesign {
        guard let referenceDesign = request.referenceDesign else {
            throw RTLVerificationExecutionError.invalidRequest("A reference design is required for formal equivalence.")
        }
        var normalized = parsed
        let selectedTop = referenceDesign.topDesignName.isEmpty
            ? normalized.design.modules.first?.name ?? ""
            : referenceDesign.topDesignName
        if request.frontend.requireTopModule,
           !normalized.design.modules.contains(where: { $0.name == selectedTop }) {
            throw RTLVerificationExecutionError.invalidRequest(
                "Reference top module \(selectedTop) was not found in the RTL input set."
            )
        }
        normalized.design.topModuleName = selectedTop
        return normalized
    }

    private func parse(
        data: Data,
        reference: RTLArtifactReference,
        topModuleName: String,
        options: RTLVerificationFrontendOptions
    ) throws -> RTLVerificationParsedDesign {
        if reference.format == .json {
            do {
                let snapshot = try LogicDesignSnapshotCodec.decode(data)
                return RTLVerificationParsedDesign(
                    design: snapshot.rtl,
                    sourcePaths: snapshot.rtl.sourceFiles.map(\.path),
                    constructCount: snapshot.rtl.modules.count,
                    unsupportedConstructs: [],
                    sourceArtifacts: snapshot.rtl.sourceFiles.enumerated().map { index, file in
                        RTLVerificationSourceArtifact(
                            path: file.path,
                            sha256: file.sha256,
                            byteCount: file.byteCount,
                            order: index
                        )
                    }
                )
            } catch {
                do {
                    let design = try JSONDecoder().decode(RTLDesign.self, from: data)
                    return RTLVerificationParsedDesign(
                        design: design,
                        sourcePaths: design.sourceFiles.map(\.path),
                        constructCount: design.modules.count,
                        unsupportedConstructs: [],
                        sourceArtifacts: design.sourceFiles.enumerated().map { index, file in
                            RTLVerificationSourceArtifact(
                                path: file.path,
                                sha256: file.sha256,
                                byteCount: file.byteCount,
                                order: index
                            )
                        }
                    )
                } catch {
                    throw RTLVerificationExecutionError.parserFailed(
                        path: reference.path,
                        reason: error.localizedDescription
                    )
                }
            }
        }
        if let systemVerilogParser = parser as? SystemVerilogRTLParser {
            return try systemVerilogParser.parse(
                data: data,
                path: reference.path,
                topModuleName: topModuleName,
                options: options
            )
        }
        return try parser.parse(data: data, path: reference.path, topModuleName: topModuleName)
    }

    private func uniqueReferences(_ references: [RTLArtifactReference]) -> [RTLArtifactReference] {
        var seen: Set<String> = []
        return references.filter { seen.insert($0.path).inserted }
    }

    private func materialize(_ locator: ArtifactLocator) throws -> RTLArtifactReference {
        let data = try reader.read(locator)
        return ArtifactReference(
            id: ArtifactID(stableKey: "rtl-locator:\(locator.location.storage.rawValue):\(locator.path)"),
            locator: locator,
            digest: try SHA256ContentDigester().digest(data: data),
            byteCount: UInt64(data.count)
        )
    }
}
