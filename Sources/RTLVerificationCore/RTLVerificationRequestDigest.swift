import Foundation

public enum RTLVerificationRequestDigest {
    public static func encode(_ request: RTLVerificationRequest) throws -> Data {
        var canonicalRequest = request
        // Qualification evidence describes the request; it is not part of
        // the verification target. Excluding it also prevents the evidence's
        // own request digest from creating a circular digest definition.
        canonicalRequest.evidenceInput = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(canonicalRequest)
    }

    public static func make(_ request: RTLVerificationRequest) throws -> String {
        RTLHasher().sha256(data: try encode(request))
    }
}
