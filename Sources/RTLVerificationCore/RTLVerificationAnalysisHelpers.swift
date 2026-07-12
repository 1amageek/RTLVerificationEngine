import Foundation
import LogicIR

public enum RTLVerificationAnalysisHelpers {
    public static func expressionNames(_ expression: RTLExpression) -> Set<String> {
        switch expression {
        case .identifier(let name):
            return [name]
        case .integer, .string:
            return []
        case .unary(_, let operand):
            return expressionNames(operand)
        case .binary(_, let left, let right):
            return expressionNames(left).union(expressionNames(right))
        case .ternary(let condition, let ifTrue, let ifFalse):
            return expressionNames(condition).union(expressionNames(ifTrue)).union(expressionNames(ifFalse))
        case .concatenate(let values):
            return values.reduce(into: Set<String>()) { result, value in result.formUnion(expressionNames(value)) }
        case .index(let value, let index):
            return expressionNames(value).union(expressionNames(index))
        case .partSelect(let value, let msb, let lsb):
            return expressionNames(value).union(expressionNames(msb)).union(expressionNames(lsb))
        }
    }

    public static func expressionBaseName(_ expression: RTLExpression) -> String? {
        switch expression {
        case .identifier(let name):
            return name
        case .index(let value, _), .partSelect(let value, _, _):
            return expressionBaseName(value)
        default:
            return nil
        }
    }

    public static func assignments(in statements: [RTLStatement]) -> [RTLAssignment] {
        statements.flatMap { statement in
            switch statement {
            case .assignment(let assignment):
                return [assignment]
            case .block(let children):
                return assignments(in: children)
            case .conditional(_, let ifTrue, let ifFalse):
                return assignments(in: ifTrue) + assignments(in: ifFalse)
            case .caseStatement(_, let items, let defaults):
                return items.flatMap { assignments(in: $0.statements) } + assignments(in: defaults)
            case .typedCaseStatement(_, _, let items, let defaults):
                return items.flatMap { assignments(in: $0.statements) } + assignments(in: defaults)
            case .null:
                return []
            }
        }
    }

    public static func allAssignments(in module: RTLModule) -> [RTLAssignment] {
        module.assignments + module.processes.flatMap { assignments(in: $0.statements) }
    }

    public static func declaredNames(in module: RTLModule) -> Set<String> {
        Set(module.ports.map(\.name) + module.signals.map(\.name) + module.memories.map(\.name) + module.parameters.map(\.name))
    }

    public static func widths(in module: RTLModule) -> [String: Int] {
        var result: [String: Int] = [:]
        for port in module.ports {
            result[port.name] = port.range?.width ?? 1
        }
        for signal in module.signals {
            result[signal.name] = signal.range?.width ?? 1
        }
        for memory in module.memories {
            result[memory.name] = memory.elementRange?.width ?? 1
        }
        return result
    }

    public static func expressionWidth(_ expression: RTLExpression, widths: [String: Int]) -> Int? {
        switch expression {
        case .identifier(let name):
            return widths[name]
        case .integer(_, let width, _):
            return width ?? 1
        case .string:
            return nil
        case .unary(_, let operand):
            return expressionWidth(operand, widths: widths)
        case .binary(_, let left, let right):
            guard let leftWidth = expressionWidth(left, widths: widths), let rightWidth = expressionWidth(right, widths: widths) else { return nil }
            return max(leftWidth, rightWidth)
        case .ternary(_, let ifTrue, let ifFalse):
            guard let trueWidth = expressionWidth(ifTrue, widths: widths), let falseWidth = expressionWidth(ifFalse, widths: widths) else { return nil }
            return max(trueWidth, falseWidth)
        case .concatenate(let values):
            let valueWidths = values.compactMap { expressionWidth($0, widths: widths) }
            return valueWidths.count == values.count ? valueWidths.reduce(0, +) : nil
        case .index:
            return 1
        case .partSelect(_, let msb, let lsb):
            guard case .integer(let msbValue, _, _) = msb, case .integer(let lsbValue, _, _) = lsb else { return nil }
            return Int(abs(msbValue - lsbValue)) + 1
        }
    }

    public static func clockName(for process: RTLProcess) -> String? {
        process.sensitivity.first {
            let value = $0.lowercased()
            return value.contains("clk") || value.contains("clock")
        } ?? (process.kind == .sequential ? process.sensitivity.first : nil)
    }

    public static func resetNames(for process: RTLProcess) -> [String] {
        process.sensitivity.filter {
            let value = $0.lowercased()
            return value.contains("rst") || value.contains("reset") || value.contains("resetn")
        }
    }
}
