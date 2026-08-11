import CircuiteFoundation
import CircuiteFoundationCrypto
import Foundation

public actor InMemoryRTLArtifactStore: RTLArtifactWriting {
    private var artifacts: [String: Data] = [:]
    public let namespace: RTLArtifactNamespace
    public let rootID: ArtifactRootID

    public init(namespace: RTLArtifactNamespace = .rtlVerification) {
        let rootID: ArtifactRootID
        do {
            rootID = try ArtifactRootID(rawValue: "rtl-verification-memory")
        } catch {
            preconditionFailure("The static in-memory artifact root identifier is invalid: \(error)")
        }
        self.namespace = namespace
        self.rootID = rootID
    }

    public init(namespace: RTLArtifactNamespace, rootID: ArtifactRootID) {
        self.namespace = namespace
        self.rootID = rootID
    }

    public func persist(
        _ data: Data,
        artifactID: String,
        runID: String
    ) async throws -> RTLArtifactBinding {
        let runSegment = try RTLArtifactPathSegment(validating: runID)
        let artifactSegment = try RTLArtifactPathSegment(validating: artifactID)
        let path = "\(namespace.relativePath)/\(runSegment.rawValue)/\(artifactSegment.rawValue).json"
        let reference = try ArtifactReference(
            digest: SHA256ContentDigester().digest(data: data),
            byteCount: UInt64(data.count),
            descriptor: ArtifactDescriptor(
                role: .output,
                kind: .report,
                format: .json
            )
        )
        if let existingData = artifacts[path] {
            throw existingData == data
                ? RTLArtifactStoreError.duplicateArtifact(path)
                : RTLArtifactStoreError.conflictingArtifact(path)
        }
        artifacts[path] = data
        return try RTLArtifactBinding(
            logicalID: artifactID,
            reference: reference,
            availability: .local(
                artifactID: reference.id,
                rootID: rootID,
                relativePath: ArtifactRelativePath(
                    segments: path.split(separator: "/").map(String.init)
                )
            )
        )
    }

    public func data(for binding: RTLArtifactBinding) -> Data? {
        artifacts[binding.sourcePath]
    }
}
