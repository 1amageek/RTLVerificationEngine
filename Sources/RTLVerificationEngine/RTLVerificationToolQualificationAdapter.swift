import Foundation
import RTLVerificationCore
import ToolQualification
import XcircuitePackage

public struct RTLVerificationToolQualificationAdapter: Sendable {
    public init() {}

    public func requirement(
        for request: RTLVerificationRequest,
        minimumLevel: ToolQualificationLevel = .productionEligible,
        qualificationScope: ToolQualificationScope? = nil
    ) -> ToolTrustRequirement {
        ToolTrustRequirement(
            kind: .rtlVerification,
            operationID: operationID(for: request),
            minimumLevel: minimumLevel,
            requiredInputFormats: [.systemVerilog, .verilog, .json],
            requiredOutputFormats: [.json],
            requiredEvidenceKinds: [.healthCheck],
            requiredQualifiedEvidenceKinds: minimumLevel == .productionEligible
                ? [.corpus, .oracle, .productionApproval]
                : [],
            requirePassingHealthCheck: true,
            qualificationScope: qualificationScope
        )
    }

    public func evaluate(
        descriptor: ToolDescriptor,
        request: RTLVerificationRequest,
        health: ToolHealthCheckResult?,
        minimumLevel: ToolQualificationLevel = .productionEligible,
        qualificationScope: ToolQualificationScope? = nil,
        evaluatedAt: Date = Date()
    ) -> ToolTrustDecision {
        ToolTrustEvaluator().evaluate(
            descriptor: descriptor,
            requirement: requirement(
                for: request,
                minimumLevel: minimumLevel,
                qualificationScope: qualificationScope
            ),
            health: health,
            evaluatedAt: evaluatedAt
        )
    }

    public func operationID(for request: RTLVerificationRequest) -> String {
        if request.analysis == .formalEquivalence {
            return "\(request.analysis.stageID).\(request.proofView.rawValue)"
        }
        return request.analysis.stageID
    }

    public func processQualificationScope(
        for request: RTLVerificationRequest,
        binaryDigest: String,
        processProfileID: String,
        pdkID: String,
        pdkDigest: String,
        deckDigest: String,
        solverID: String? = nil,
        solverVersion: String? = nil
    ) -> RTLVerificationProcessQualificationScope {
        RTLVerificationProcessQualificationScope(
            implementationID: RTLVerificationExecutionSupport.implementationID,
            binaryDigest: binaryDigest,
            algorithmVersion: RTLVerificationExecutionSupport.implementationVersion,
            processProfileID: processProfileID,
            pdkID: pdkID,
            pdkDigest: pdkDigest,
            deckDigest: deckDigest,
            solverID: solverID,
            solverVersion: solverVersion,
            analyses: [request.analysis],
            proofViews: request.analysis == .formalEquivalence ? [request.proofView] : []
        )
    }
}
