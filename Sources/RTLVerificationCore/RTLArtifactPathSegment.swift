import Foundation

public struct RTLArtifactPathSegment: Sendable, Hashable, Codable, RawRepresentable {
    public static let rtlVerification = RTLArtifactPathSegment(validated: "rtl-verification")

    public let rawValue: String

    public init?(rawValue: String) {
        do {
            try self.init(validating: rawValue)
        } catch {
            return nil
        }
    }

    public init(validating rawValue: String) throws {
        guard !rawValue.isEmpty,
              rawValue != ".",
              rawValue != "..",
              rawValue.utf8.count <= 255,
              rawValue.unicodeScalars.allSatisfy({ scalar in
                  CharacterSet.alphanumerics.contains(scalar)
                      || scalar == "-"
                      || scalar == "_"
                      || scalar == "."
              }) else {
            throw RTLArtifactStoreError.invalidPathSegment(rawValue)
        }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(validating: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private init(validated rawValue: String) {
        self.rawValue = rawValue
    }
}
