import CircuiteFoundation
import Foundation

public enum RTLArtifactBindingError: Error, Sendable, Equatable {
    case emptyLogicalID
    case availabilityIdentityMismatch
    case missingBinding(ArtifactID)
    case localAvailabilityRequired(String)
}

/// Binds location-independent artifact identity to one execution-scoped availability.
public struct RTLArtifactBinding: Sendable, Hashable, Codable {
    public let logicalID: String
    public let reference: ArtifactReference
    public let availability: ArtifactAvailability

    public init(
        logicalID: String,
        reference: ArtifactReference,
        availability: ArtifactAvailability
    ) throws {
        guard !logicalID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLArtifactBindingError.emptyLogicalID
        }
        guard reference.id == availability.artifactID else {
            throw RTLArtifactBindingError.availabilityIdentityMismatch
        }
        self.logicalID = logicalID
        self.reference = reference
        self.availability = availability
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            logicalID: container.decode(String.self, forKey: .logicalID),
            reference: container.decode(ArtifactReference.self, forKey: .reference),
            availability: container.decode(ArtifactAvailability.self, forKey: .availability)
        )
    }

    public var descriptor: ArtifactDescriptor { reference.descriptor }
    public var sourcePath: String {
        switch availability {
        case .local(_, _, let relativePath):
            relativePath.stringValue
        case .service(_, let resource):
            String(describing: resource)
        }
    }

    public func requireLocalRelativePath() throws -> ArtifactRelativePath {
        guard case .local(_, _, let relativePath) = availability else {
            throw RTLArtifactBindingError.localAvailabilityRequired(logicalID)
        }
        return relativePath
    }

    public static func require(
        _ reference: ArtifactReference,
        in bindings: [RTLArtifactBinding]
    ) throws -> RTLArtifactBinding {
        guard let binding = bindings.first(where: { $0.reference == reference }) else {
            throw RTLArtifactBindingError.missingBinding(reference.id)
        }
        return binding
    }
}
