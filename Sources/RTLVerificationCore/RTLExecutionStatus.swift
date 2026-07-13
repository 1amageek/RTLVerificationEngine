import Foundation

public enum RTLExecutionStatus: String, Sendable, Hashable, Codable {
    case completed
    case failed
    case blocked
    case cancelled
}
