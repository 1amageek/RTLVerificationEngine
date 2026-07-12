import LogicIR
import LogicEngineCore
import RTLVerificationCore

struct RTLStructuralEquivalenceComparator: Sendable {
    struct Comparison: Sendable, Hashable {
        var mismatches: [String]
        var affectedEntities: [String]
    }

    func compare(_ implementation: RTLDesign, _ reference: RTLDesign) -> Comparison {
        var mismatches: [String] = []
        var entities: [String] = []
        if implementation.topModuleName != reference.topModuleName {
            mismatches.append("Top module differs: \(implementation.topModuleName) != \(reference.topModuleName)")
            entities.append(implementation.topModuleName)
        }
        let implementationModules = Dictionary(uniqueKeysWithValues: implementation.modules.map { ($0.name, canonicalModule($0)) })
        let referenceModules = Dictionary(uniqueKeysWithValues: reference.modules.map { ($0.name, canonicalModule($0)) })
        for name in Set(implementationModules.keys).union(referenceModules.keys).sorted() {
            guard let lhs = implementationModules[name], let rhs = referenceModules[name] else {
                mismatches.append("Module presence differs: \(name)")
                entities.append(name)
                continue
            }
            if lhs != rhs {
                mismatches.append("Canonical module differs: \(name)")
                entities.append(name)
            }
        }
        return Comparison(mismatches: mismatches, affectedEntities: entities)
    }

    func compare(_ implementation: LogicDesignDocument, _ reference: LogicDesignDocument) -> Comparison {
        let implementationCanonical = canonicalDocument(implementation)
        let referenceCanonical = canonicalDocument(reference)
        guard implementationCanonical != referenceCanonical else {
            return Comparison(mismatches: [], affectedEntities: [])
        }
        return Comparison(
            mismatches: ["Mapped execution graph differs for top module \(implementation.topDesignName)"],
            affectedEntities: [implementation.topDesignName]
        )
    }

    private func canonicalModule(_ module: RTLModule) -> String {
        let ports = module.ports.map {
            "port:\($0.name):\($0.direction.rawValue):\($0.dataType.rawValue):\($0.range?.msb ?? 0):\($0.range?.lsb ?? 0)"
        }.sorted().joined(separator: "|")
        let signals = module.signals.map {
            "signal:\($0.name):\($0.dataType.rawValue):\($0.storage.rawValue):\($0.range?.msb ?? 0):\($0.range?.lsb ?? 0)"
        }.sorted().joined(separator: "|")
        let assignments = RTLVerificationAnalysisHelpers.allAssignments(in: module).map { assignment in
            "\(expressionText(assignment.target))=\(expressionText(assignment.value)):\(assignment.nonBlocking)"
        }.sorted().joined(separator: "|")
        let instances = module.instances.map { instance in
            "instance:\(instance.moduleName):\(instance.instanceName):\(instance.connections.map { "\($0.portName)=\(expressionText($0.expression))" }.sorted().joined(separator: ","))"
        }.sorted().joined(separator: "|")
        return "\(module.name);\(ports);\(signals);\(assignments);\(instances)"
    }

    private func canonicalDocument(_ document: LogicDesignDocument) -> String {
        let ports = document.ports.map { "port:\($0.name):\($0.direction.rawValue):\($0.width)" }
            .sorted()
            .joined(separator: "|")
        let signals = document.signals.map { "signal:\($0.name):\($0.width)" }
            .sorted()
            .joined(separator: "|")
        let nodes = document.nodes.map { node in
            let parameters = node.parameters.map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ",")
            return "node:\(node.id):\(node.kind.rawValue):\(node.inputs.joined(separator: ",")): \(node.outputs.joined(separator: ",")):\(parameters)"
        }
        .sorted()
        .joined(separator: "|")
        return "\(document.topDesignName);\(ports);\(signals);\(nodes)"
    }

    private func expressionText(_ expression: RTLExpression) -> String {
        switch expression {
        case .identifier(let name): return name
        case .integer(let value, let width, let isSigned): return "integer:\(value):\(width ?? 0):\(isSigned)"
        case .string(let value): return "string:\(value)"
        case .unary(let op, let operand): return "(\(op)\(expressionText(operand)))"
        case .binary(let op, let left, let right): return "(\(expressionText(left))\(op)\(expressionText(right)))"
        case .ternary(let condition, let ifTrue, let ifFalse): return "(\(expressionText(condition))?\(expressionText(ifTrue)):\(expressionText(ifFalse)))"
        case .concatenate(let values): return "{\(values.map(expressionText).joined(separator: ","))}"
        case .index(let value, let index): return "\(expressionText(value))[\(expressionText(index))]"
        case .partSelect(let value, let msb, let lsb): return "\(expressionText(value))[\(expressionText(msb)): \(expressionText(lsb))]"
        }
    }
}
