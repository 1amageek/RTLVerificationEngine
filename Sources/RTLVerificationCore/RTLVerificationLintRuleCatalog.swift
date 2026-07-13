import Foundation
import XcircuitePackage

public enum RTLVerificationLintRuleCatalog {
    public static let schemaVersion = 1

    public struct Rule: Sendable, Hashable, Codable {
        public var code: String
        public var severity: XcircuiteEngineDiagnosticSeverity
        public var title: String
        public var description: String
        public var suggestedActions: [String]

        public init(
            code: String,
            severity: XcircuiteEngineDiagnosticSeverity,
            title: String,
            description: String,
            suggestedActions: [String]
        ) {
            self.code = code
            self.severity = severity
            self.title = title
            self.description = description
            self.suggestedActions = suggestedActions
        }
    }

    public static let rules: [Rule] = [
        Rule(
            code: "LOGIC_TOP_MISSING",
            severity: .error,
            title: "Top module missing",
            description: "The canonical design does not identify a top module.",
            suggestedActions: ["select_top_module"]
        ),
        Rule(
            code: "LOGIC_TOP_UNRESOLVED",
            severity: .error,
            title: "Top module unresolved",
            description: "The selected top module is not defined in the design.",
            suggestedActions: ["add_module_definition", "select_existing_top"]
        ),
        Rule(
            code: "LOGIC_DUPLICATE_MODULE",
            severity: .error,
            title: "Duplicate module",
            description: "Module names must be unique in a canonical design.",
            suggestedActions: ["rename_duplicate_module"]
        ),
        Rule(
            code: "LOGIC_DUPLICATE_SYMBOL",
            severity: .error,
            title: "Duplicate symbol",
            description: "A module contains duplicate port, signal or memory declarations.",
            suggestedActions: ["rename_duplicate_symbol"]
        ),
        Rule(
            code: "LOGIC_INSTANCE_UNRESOLVED",
            severity: .error,
            title: "Instance type unresolved",
            description: "An instance references a module that is not defined in the source set.",
            suggestedActions: ["add_referenced_module", "correct_instance_type"]
        ),
        Rule(
            code: "LOGIC_REFERENCE_UNRESOLVED",
            severity: .error,
            title: "Signal reference unresolved",
            description: "An expression references an undefined signal, port or memory.",
            suggestedActions: ["declare_signal", "correct_reference"]
        ),
        Rule(
            code: "RTL_WIDTH_MISMATCH",
            severity: .error,
            title: "Assignment width mismatch",
            description: "An assignment expression width differs from the target width.",
            suggestedActions: ["resize_expression", "declare_matching_width"]
        ),
        Rule(
            code: "RTL_MULTIPLE_DRIVER",
            severity: .error,
            title: "Multiple signal drivers",
            description: "A signal has more than one procedural or continuous driver.",
            suggestedActions: ["merge_drivers", "use_one_driver_per_signal"]
        ),
        Rule(
            code: "RTL_SEQUENTIAL_BLOCKING_ASSIGNMENT",
            severity: .warning,
            title: "Blocking assignment in sequential logic",
            description: "A sequential process uses a blocking assignment.",
            suggestedActions: ["use_nonblocking_assignment"]
        ),
        Rule(
            code: "RTL_COMBINATIONAL_LOOP",
            severity: .error,
            title: "Combinational loop",
            description: "A combinational assignment cycle was detected.",
            suggestedActions: ["break_feedback_path", "add_sequential_storage"]
        ),
        Rule(
            code: "RTL_OUTPUT_UNDRIVEN",
            severity: .warning,
            title: "Undriven output",
            description: "An output port has no assignment in the analyzed RTL.",
            suggestedActions: ["drive_output", "confirm_intentional_constant"]
        )
    ]

    public static func rule(for code: String) -> Rule? {
        rules.first { $0.code == code }
    }
}
