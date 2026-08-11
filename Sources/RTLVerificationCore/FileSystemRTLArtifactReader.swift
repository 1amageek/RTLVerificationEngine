import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuiteFoundationFileSystem
import Foundation

public actor FileSystemRTLArtifactReader: RTLArtifactReading {
    public nonisolated let rootID: ArtifactRootID

    private let access: any ArtifactAccessing
    private let budget: ArtifactAccessBudget
    private let ownedRoot: ArtifactRootCapability?

    public init(projectRoot: URL) throws {
        try self.init(
            projectRoot: projectRoot,
            rootID: ArtifactRootID(rawValue: "rtl-verification-project")
        )
    }

    public init(projectRoot: URL, rootID: ArtifactRootID) throws {
        let root = try ArtifactRootCapability(
            rootID: rootID,
            directoryURL: projectRoot,
            digester: SHA256ContentDigester()
        )
        self.rootID = rootID
        self.access = root
        self.ownedRoot = root
        self.budget = try Self.defaultBudget()
    }

    public init(
        rootID: ArtifactRootID,
        access: any ArtifactAccessing,
        budget: ArtifactAccessBudget
    ) {
        self.rootID = rootID
        self.access = access
        self.budget = budget
        self.ownedRoot = nil
    }

    public func read(_ binding: RTLArtifactBinding) async throws -> Data {
        let intent: ArtifactAccessIntent
        do {
            intent = try ArtifactAccessIntent(
                expectedReference: binding.reference,
                availability: binding.availability,
                operation: .read,
                budget: budget
            )
        } catch {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: binding.sourcePath,
                reason: String(describing: error)
            )
        }

        let session: any ArtifactReadSession
        do {
            session = try await access.open(intent)
        } catch {
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: binding.sourcePath,
                reason: String(describing: error)
            )
        }

        do {
            var data = Data()
            var offset: UInt64 = 0
            while true {
                let page = try await session.readPage(
                    ArtifactReadPageRequest(
                        offset: offset,
                        maximumByteCount: budget.maximumPageByteCount
                    )
                )
                page.bytes.withUnsafeBytes { bytes in
                    data.append(contentsOf: bytes)
                }
                offset = page.cumulativeByteCount
                if page.completion == .complete {
                    break
                }
            }
            _ = try await session.close().wait()
            return data
        } catch let primaryError {
            do {
                _ = try await session.close().wait()
            } catch let closeError {
                throw RTLVerificationExecutionError.artifactReadFailed(
                    path: binding.sourcePath,
                    reason: "read failed: \(primaryError); close failed: \(closeError)"
                )
            }
            throw RTLVerificationExecutionError.artifactReadFailed(
                path: binding.sourcePath,
                reason: String(describing: primaryError)
            )
        }
    }

    public func shutdown() async throws {
        guard let ownedRoot else {
            return
        }
        try await ownedRoot.close().wait()
    }

    private static func defaultBudget() throws -> ArtifactAccessBudget {
        try ArtifactAccessBudget(
            maximumPageByteCount: 1_048_576,
            maximumTotalByteCount: 1_073_741_824,
            maximumPageCount: 1_024,
            maximumWorkUnitCount: 4_096,
            maximumDurationNanoseconds: 60_000_000_000
        )
    }
}
