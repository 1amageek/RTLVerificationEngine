import CircuiteFoundation

/// Foundation-backed artifact identity used by RTL verification contracts.
public typealias RTLArtifactReference = ArtifactReference

public extension ArtifactReference {
    var path: String {
        locator.location.value
    }

    var artifactID: String? {
        id.rawValue
    }

    var sha256: String? {
        digest.algorithm == .sha256 ? digest.hexadecimalValue : nil
    }
}
