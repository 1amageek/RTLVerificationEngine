import Foundation

public enum RTLVerificationProofView: String, Sendable, Hashable, Codable, CaseIterable {
    case rtlToRtlStructural
    case rtlToMappedExecutionStructural
    case rtlToSynthesized
    case synthesizedToDFT

    public var requiresSolver: Bool {
        switch self {
        case .rtlToRtlStructural, .rtlToMappedExecutionStructural:
            return false
        case .rtlToSynthesized, .synthesizedToDFT:
            return true
        }
    }
}
