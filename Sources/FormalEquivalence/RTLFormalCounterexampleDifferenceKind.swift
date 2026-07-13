import Foundation

public enum RTLFormalCounterexampleDifferenceKind: String, Sendable, Hashable, Codable, CaseIterable {
    case topModule
    case modulePresence
    case moduleStructure
    case mappedExecutionGraph
}
