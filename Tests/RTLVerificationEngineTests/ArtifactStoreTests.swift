import Foundation
import Testing
@testable import RTLVerificationCore

@Suite("RTL artifact stores")
struct ArtifactStoreTests {
    @Test("path segments reject traversal and separators")
    func pathSegmentsRejectUnsafeValues() throws {
        #expect(throws: RTLArtifactStoreError.invalidPathSegment("..")) {
            _ = try RTLArtifactPathSegment(validating: "..")
        }
        #expect(throws: RTLArtifactStoreError.invalidPathSegment("run/escape")) {
            _ = try RTLArtifactPathSegment(validating: "run/escape")
        }
        #expect(throws: RTLArtifactStoreError.invalidPathSegment("run\\escape")) {
            _ = try RTLArtifactPathSegment(validating: "run\\escape")
        }
        #expect(try RTLArtifactNamespace(validating: ".xcircuite/runs").relativePath == ".xcircuite/runs")
        #expect(throws: RTLArtifactStoreError.invalidNamespace("/runs")) {
            _ = try RTLArtifactNamespace(validating: "/runs")
        }
    }

    @Test("in-memory storage is immutable")
    func inMemoryStorageRejectsDuplicatesAndConflicts() async throws {
        let store = InMemoryRTLArtifactStore()
        let data = Data("first".utf8)
        let reference = try await store.persist(data, artifactID: "report", runID: "run-1")
        #expect(reference.path == "rtl-verification/run-1/report.json")

        await #expect(throws: RTLArtifactStoreError.duplicateArtifact(reference.path)) {
            _ = try await store.persist(data, artifactID: "report", runID: "run-1")
        }
        await #expect(throws: RTLArtifactStoreError.conflictingArtifact(reference.path)) {
            _ = try await store.persist(Data("second".utf8), artifactID: "report", runID: "run-1")
        }
    }

    @Test("file-system storage is contained and immutable")
    func fileSystemStorageRejectsDuplicatesAndConflicts() async throws {
        let root = try temporaryDirectory(named: "immutable")
        defer { removeTemporaryDirectory(root) }
        let store = try FileSystemRTLArtifactStore(
            artifactRoot: root,
            namespace: .rtlVerification
        )
        let data = Data("first".utf8)
        let reference = try await store.persist(data, artifactID: "report", runID: "run-1")
        #expect(reference.path == "rtl-verification/run-1/report.json")
        #expect(try Data(contentsOf: root.appending(path: reference.path)) == data)

        await #expect(throws: RTLArtifactStoreError.duplicateArtifact(reference.path)) {
            _ = try await store.persist(data, artifactID: "report", runID: "run-1")
        }
        await #expect(throws: RTLArtifactStoreError.conflictingArtifact(reference.path)) {
            _ = try await store.persist(Data("second".utf8), artifactID: "report", runID: "run-1")
        }
    }

    @Test("file-system storage rejects symbolic-link escapes")
    func fileSystemStorageRejectsSymbolicLinkEscape() async throws {
        let root = try temporaryDirectory(named: "symlink-root")
        let outside = try temporaryDirectory(named: "symlink-outside")
        defer {
            removeTemporaryDirectory(root)
            removeTemporaryDirectory(outside)
        }
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "rtl-verification"),
            withDestinationURL: outside
        )
        let store = try FileSystemRTLArtifactStore(
            artifactRoot: root,
            namespace: .rtlVerification
        )

        await #expect(throws: RTLArtifactStoreError.symbolicLinkInPath(
            root.appending(path: "rtl-verification").path(percentEncoded: false)
        )) {
            _ = try await store.persist(Data("data".utf8), artifactID: "report", runID: "run-1")
        }
    }

    @Test("file-system storage revalidates a root created after initialization")
    func fileSystemStorageRejectsRootReplacedBySymbolicLink() async throws {
        let parent = try temporaryDirectory(named: "late-symlink-parent")
        let outside = try temporaryDirectory(named: "late-symlink-outside")
        defer {
            removeTemporaryDirectory(parent)
            removeTemporaryDirectory(outside)
        }
        let root = parent.appending(path: "artifacts")
        let store = try FileSystemRTLArtifactStore(
            artifactRoot: root,
            namespace: .rtlVerification
        )
        try FileManager.default.createSymbolicLink(
            at: root,
            withDestinationURL: outside
        )

        await #expect(throws: RTLArtifactStoreError.rootIsSymbolicLink(
            root.path(percentEncoded: false)
        )) {
            _ = try await store.persist(
                Data("data".utf8),
                artifactID: "report",
                runID: "run-1"
            )
        }
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "rtl-artifact-store-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func removeTemporaryDirectory(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("Failed to remove temporary RTL artifact directory: \(error)")
        }
    }
}
