import Foundation
import XcircuitePackage
import LogicIR
import TimingCore

public struct RTLVerificationRequest: XcircuiteEngineRequest {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var runID: String
    public var inputs: [XcircuiteFileReference]

    public var design: LogicDesignReference
    public var referenceDesign: LogicDesignReference?
    public var referenceInputs: [XcircuiteFileReference]
    public var constraints: TimingConstraintReference?
    public var analysis: RTLVerificationAnalysis
    public var policy: RTLVerificationPolicy
    public var waivers: [RTLVerificationWaiver]
    public var frontend: RTLVerificationFrontendOptions
    public var proofView: RTLVerificationProofView
    public var assumptions: [RTLVerificationAssumption]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case runID
        case inputs
        case design
        case referenceDesign
        case referenceInputs
        case constraints
        case analysis
        case policy
        case waivers
        case frontend
        case proofView
        case assumptions
    }

    public init(
        runID: String,
        inputs: [XcircuiteFileReference],
        design: LogicDesignReference,
        referenceDesign: LogicDesignReference? = nil,
        referenceInputs: [XcircuiteFileReference] = [],
        constraints: TimingConstraintReference? = nil,
        analysis: RTLVerificationAnalysis = .lint,
        policy: RTLVerificationPolicy = RTLVerificationPolicy(),
        waivers: [RTLVerificationWaiver] = [],
        frontend: RTLVerificationFrontendOptions = RTLVerificationFrontendOptions(),
        proofView: RTLVerificationProofView = .rtlToRtlStructural,
        assumptions: [RTLVerificationAssumption] = []
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.inputs = inputs
        self.design = design
        self.referenceDesign = referenceDesign
        self.referenceInputs = referenceInputs
        self.constraints = constraints
        self.analysis = analysis
        self.policy = policy
        self.waivers = waivers
        self.frontend = frontend
        self.proofView = proofView
        self.assumptions = assumptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported RTL verification request schema version \(schemaVersion)."
            )
        }
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            inputs: try container.decode([XcircuiteFileReference].self, forKey: .inputs),
            design: try container.decode(LogicDesignReference.self, forKey: .design),
            referenceDesign: try container.decodeIfPresent(LogicDesignReference.self, forKey: .referenceDesign),
            referenceInputs: try container.decodeIfPresent([XcircuiteFileReference].self, forKey: .referenceInputs) ?? [],
            constraints: try container.decodeIfPresent(TimingConstraintReference.self, forKey: .constraints),
            analysis: try container.decodeIfPresent(RTLVerificationAnalysis.self, forKey: .analysis) ?? .lint,
            policy: try container.decodeIfPresent(RTLVerificationPolicy.self, forKey: .policy) ?? RTLVerificationPolicy(),
            waivers: try container.decodeIfPresent([RTLVerificationWaiver].self, forKey: .waivers) ?? [],
            frontend: try container.decodeIfPresent(RTLVerificationFrontendOptions.self, forKey: .frontend) ?? RTLVerificationFrontendOptions(),
            proofView: try container.decodeIfPresent(RTLVerificationProofView.self, forKey: .proofView) ?? .rtlToRtlStructural,
            assumptions: try container.decodeIfPresent([RTLVerificationAssumption].self, forKey: .assumptions) ?? []
        )
    }
}
