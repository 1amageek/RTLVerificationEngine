import Foundation
import CircuiteFoundation
import CircuiteFoundationCrypto
import RTLVerificationCore

/// Creates a canonical Foundation artifact binding for deterministic test input.
func makeTestArtifactBinding(
    artifactID: String? = nil,
    path: String,
    kind: ArtifactKind,
    format: ArtifactFormat,
    role: ArtifactRole = .input,
    data: Data? = nil,
    sha256: String? = nil,
    byteCount: Int64? = nil
) -> RTLArtifactBinding {
    do {
        let canonicalData = data ?? Data()
        let bytes = UInt64(max(0, byteCount ?? Int64(canonicalData.count)))
        let digest = try ContentDigest(
            algorithm: .sha256,
            hexadecimalValue: sha256 ?? SHA256ContentDigester().sha256(data: canonicalData)
        )
        let reference = try ArtifactReference(
            digest: digest,
            byteCount: bytes,
            descriptor: ArtifactDescriptor(role: role, kind: kind, format: format)
        )
        let relativePath = try ArtifactRelativePath(
            segments: path.split(separator: "/").map(String.init)
        )
        return try RTLArtifactBinding(
            logicalID: artifactID ?? "test-artifact-\(reference.id.description)",
            reference: reference,
            availability: .local(
                artifactID: reference.id,
                rootID: try ArtifactRootID(rawValue: "rtl-verification-test"),
                relativePath: relativePath
            )
        )
    } catch {
        preconditionFailure("Invalid test artifact fixture: \(error)")
    }
}

/// Creates a canonical Foundation artifact for deterministic test input.
func makeTestArtifactReference(
    artifactID: String? = nil,
    path: String,
    kind: ArtifactKind,
    format: ArtifactFormat,
    role: ArtifactRole = .input,
    data: Data? = nil,
    sha256: String? = nil,
    byteCount: Int64? = nil
) -> ArtifactReference {
    makeTestArtifactBinding(
        artifactID: artifactID,
        path: path,
        kind: kind,
        format: format,
        role: role,
        data: data,
        sha256: sha256,
        byteCount: byteCount
    ).reference
}

extension InMemoryRTLArtifactReader {
    init(testArtifacts: [RTLArtifactBinding: Data]) {
        self.init(
            bindings: Array(testArtifacts.keys),
            dataByLogicalID: Dictionary(
                uniqueKeysWithValues: testArtifacts.map { binding, data in
                    (binding.logicalID, data)
                }
            )
        )
    }

    init(artifacts: [String: Data]) {
        do {
            self.init(artifacts: try Dictionary(
                uniqueKeysWithValues: artifacts.values.map { data in
                    let digest = try SHA256ContentDigester().digest(data: data)
                    return (
                        try ArtifactID(digest: digest, byteCount: UInt64(data.count)),
                        data
                    )
                }
            ))
        } catch {
            preconditionFailure("Invalid in-memory test artifact: \(error)")
        }
    }
}

extension RTLArtifactBinding {
    var path: String { sourcePath }
}

extension SHA256ContentDigester {
    func sha256(data: Data) -> String {
        do {
            return try digest(data: data).hexadecimalValue
        } catch {
            preconditionFailure("SHA-256 is unavailable in the test fixture: \(error)")
        }
    }
}
