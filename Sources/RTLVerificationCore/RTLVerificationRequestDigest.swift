import Foundation
import XcircuitePackage

public enum RTLVerificationRequestDigest {
    public static func encode(_ request: RTLVerificationRequest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(request)
    }

    public static func make(_ request: RTLVerificationRequest) throws -> String {
        XcircuiteHasher().sha256(data: try encode(request))
    }
}
