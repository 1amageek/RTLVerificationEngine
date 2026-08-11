import CircuiteFoundation
import Foundation
import LogicIR
import PowerIntent
import TimingCore

public struct RTLVerificationRequest: RTLExecutionRequest {
    public static let currentSchemaVersion = 3

    public private(set) var schemaVersion: Int
    public var runID: String
    public private(set) var inputs: [ArtifactReference]
    public private(set) var inputBindings: [RTLArtifactBinding]

    public var design: LogicDesignReference
    public var referenceDesign: LogicDesignReference?
    public private(set) var referenceInputBindings: [RTLArtifactBinding]
    public var constraints: RTLConstraintReference?
    public var resetIntent: RTLResetIntentReference?
    public var powerIntent: PowerIntentReference?
    public var analysis: RTLVerificationAnalysis
    public var policy: RTLVerificationPolicy
    public var waivers: [RTLVerificationWaiver]
    public var frontend: RTLVerificationFrontendOptions
    public var proofView: RTLVerificationProofView
    public var assumptions: [RTLVerificationAssumption]
    public var evidenceInput: RTLVerificationEvidenceInput?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case inputBindings
        case design
        case referenceDesign
        case referenceInputBindings
        case constraints
        case resetIntent
        case powerIntent
        case analysis
        case policy
        case waivers
        case frontend
        case proofView
        case assumptions
        case evidenceInput
    }

    public init(
        runID: String,
        inputBindings: [RTLArtifactBinding],
        design: LogicDesignReference,
        referenceDesign: LogicDesignReference? = nil,
        referenceInputBindings: [RTLArtifactBinding] = [],
        constraints: RTLConstraintReference? = nil,
        resetIntent: RTLResetIntentReference? = nil,
        powerIntent: PowerIntentReference? = nil,
        analysis: RTLVerificationAnalysis = .lint,
        policy: RTLVerificationPolicy = RTLVerificationPolicy(),
        waivers: [RTLVerificationWaiver] = [],
        frontend: RTLVerificationFrontendOptions = RTLVerificationFrontendOptions(),
        proofView: RTLVerificationProofView = .rtlToRtlStructural,
        assumptions: [RTLVerificationAssumption] = [],
        evidenceInput: RTLVerificationEvidenceInput? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputBindings = inputBindings
        self.referenceInputBindings = referenceInputBindings
        self.inputs = Self.uniqueReferences(
            (inputBindings + referenceInputBindings).map(\.reference)
        )
        self.design = design
        self.referenceDesign = referenceDesign
        self.constraints = constraints
        self.resetIntent = resetIntent
        self.powerIntent = powerIntent
        self.analysis = analysis
        self.policy = policy
        self.waivers = waivers
        self.frontend = frontend
        self.proofView = proofView
        self.assumptions = assumptions
        self.evidenceInput = evidenceInput
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL verification request schema version \(schemaVersion)."
            )
        }
        let inputBindings = try container.decode([RTLArtifactBinding].self, forKey: .inputBindings)
        let referenceInputBindings = try container.decode(
            [RTLArtifactBinding].self,
            forKey: .referenceInputBindings
        )
        let inputs = try container.decode([ArtifactReference].self, forKey: .inputs)
        guard inputs == Self.uniqueReferences(
            (inputBindings + referenceInputBindings).map(\.reference)
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .inputs,
                in: container,
                debugDescription: "RTL verification inputs do not match their artifact bindings."
            )
        }
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            inputBindings: inputBindings,
            design: try container.decode(LogicDesignReference.self, forKey: .design),
            referenceDesign: try container.decodeIfPresent(LogicDesignReference.self, forKey: .referenceDesign),
            referenceInputBindings: referenceInputBindings,
            constraints: try container.decodeIfPresent(RTLConstraintReference.self, forKey: .constraints),
            resetIntent: try container.decodeIfPresent(
                RTLResetIntentReference.self,
                forKey: .resetIntent
            ),
            powerIntent: try container.decodeIfPresent(
                PowerIntentReference.self,
                forKey: .powerIntent
            ),
            analysis: try container.decode(RTLVerificationAnalysis.self, forKey: .analysis),
            policy: try container.decode(RTLVerificationPolicy.self, forKey: .policy),
            waivers: try container.decode([RTLVerificationWaiver].self, forKey: .waivers),
            frontend: try container.decode(RTLVerificationFrontendOptions.self, forKey: .frontend),
            proofView: try container.decode(RTLVerificationProofView.self, forKey: .proofView),
            assumptions: try container.decode([RTLVerificationAssumption].self, forKey: .assumptions),
            evidenceInput: try container.decodeIfPresent(
                RTLVerificationEvidenceInput.self,
                forKey: .evidenceInput
            )
        )
    }
}

public extension RTLVerificationRequest {
    var executionInputArtifacts: [ArtifactReference] {
        var references = inputs + [design.artifact]
        if let referenceDesign {
            references.append(referenceDesign.artifact)
        }
        if let constraints {
            references.append(constraints.artifact)
        }
        if let resetIntent {
            references.append(resetIntent.artifact)
        }
        if let powerIntent {
            references.append(powerIntent.artifact)
        }
        var identities = Set<ArtifactID>()
        return references.filter { identities.insert($0.id).inserted }
    }

    func requireBinding(for reference: ArtifactReference) throws -> RTLArtifactBinding {
        do {
            return try RTLArtifactBinding.require(reference, in: inputBindings)
        } catch {
            throw RTLVerificationExecutionError.invalidRequest(
                "Artifact materialization is missing for content \(reference.id.description)."
            )
        }
    }

    func requireReferenceBinding(
        for reference: ArtifactReference
    ) throws -> RTLArtifactBinding {
        do {
            return try RTLArtifactBinding.require(reference, in: referenceInputBindings)
        } catch {
            throw RTLVerificationExecutionError.invalidRequest(
                "Reference artifact materialization is missing for content \(reference.id.description)."
            )
        }
    }

    mutating func replaceInputBindings(_ bindings: [RTLArtifactBinding]) {
        inputBindings = bindings
        updateInputs()
    }

    mutating func appendInputBindings(_ bindings: [RTLArtifactBinding]) {
        replaceInputBindings(inputBindings + bindings)
    }

    mutating func replaceReferenceInputBindings(
        _ bindings: [RTLArtifactBinding]
    ) {
        referenceInputBindings = bindings
        updateInputs()
    }

    mutating func appendReferenceInputBindings(
        _ bindings: [RTLArtifactBinding]
    ) {
        replaceReferenceInputBindings(referenceInputBindings + bindings)
    }

    func designSubjectReference() throws -> DesignSubjectReference {
        .path(
            try DesignPathReference(
                facetID: DesignFacetID(rawValue: "rtl"),
                kindID: DesignEntityKindID(rawValue: "design"),
                localIdentifier: design.topDesignName
            )
        )
    }

    private mutating func updateInputs() {
        inputs = Self.uniqueReferences(
            (inputBindings + referenceInputBindings).map(\.reference)
        )
    }
}

private extension RTLVerificationRequest {
    static func uniqueReferences(_ references: [ArtifactReference]) -> [ArtifactReference] {
        var identities = Set<ArtifactID>()
        return references.filter { identities.insert($0.id).inserted }
    }
}
