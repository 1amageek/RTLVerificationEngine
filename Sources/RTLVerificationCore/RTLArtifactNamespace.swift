import Foundation

public struct RTLArtifactNamespace: Sendable, Hashable, Codable {
    public static let rtlVerification = RTLArtifactNamespace(
        validatedSegments: [.rtlVerification]
    )

    public let segments: [RTLArtifactPathSegment]

    public init(segments: [RTLArtifactPathSegment]) throws {
        guard !segments.isEmpty else {
            throw RTLArtifactStoreError.invalidNamespace("")
        }
        self.segments = segments
    }

    public init(validating path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty, !components.contains(where: { $0.isEmpty }) else {
            throw RTLArtifactStoreError.invalidNamespace(path)
        }
        do {
            segments = try components.map {
                try RTLArtifactPathSegment(validating: String($0))
            }
        } catch {
            throw RTLArtifactStoreError.invalidNamespace(path)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(validating: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(relativePath)
    }

    public var relativePath: String {
        segments.map(\.rawValue).joined(separator: "/")
    }

    private init(validatedSegments: [RTLArtifactPathSegment]) {
        segments = validatedSegments
    }
}
