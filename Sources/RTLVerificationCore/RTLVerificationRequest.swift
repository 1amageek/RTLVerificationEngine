import CircuiteFoundation
import Foundation
import LogicIR
import PowerIntent
import TimingCore

public struct RTLVerificationRequest: RTLExecutionRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [ArtifactReference]

    public var design: LogicDesignReference
    public var referenceDesign: LogicDesignReference?
    public var referenceInputs: [ArtifactReference]
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
        case design
        case referenceDesign
        case referenceInputs
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
        inputs: [ArtifactReference],
        design: LogicDesignReference,
        referenceDesign: LogicDesignReference? = nil,
        referenceInputs: [ArtifactReference] = [],
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
        self.inputs = inputs
        self.design = design
        self.referenceDesign = referenceDesign
        self.referenceInputs = referenceInputs
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
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            inputs: try container.decode([ArtifactReference].self, forKey: .inputs),
            design: try container.decode(LogicDesignReference.self, forKey: .design),
            referenceDesign: try container.decodeIfPresent(LogicDesignReference.self, forKey: .referenceDesign),
            referenceInputs: try container.decode([ArtifactReference].self, forKey: .referenceInputs),
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
        var references = inputs + [design.artifact] + referenceInputs
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
        var paths = Set<String>()
        return references.filter { paths.insert($0.path).inserted }
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
}
