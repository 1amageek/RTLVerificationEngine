import Foundation
import RTLVerificationCore
import ToolQualification

public struct RTLVerificationToolTrustPolicy: Sendable {
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
                ? [.corpus, .oracle]
                : [],
            requirePassingHealthCheck: true,
            qualificationScope: qualificationScope,
            requireIndependentQualificationEvidence: minimumLevel == .productionEligible
        )
    }

    public func evaluate(
        descriptor: ToolDescriptor,
        request: RTLVerificationRequest,
        health: ToolHealthCheckResult?,
        minimumLevel: ToolQualificationLevel = .productionEligible,
        qualificationScope: ToolQualificationScope? = nil,
        artifactReader: (any ToolQualificationArtifactReading)? = nil,
        evaluatedAt: Date = Date()
    ) async -> ToolTrustDecision {
        await ToolTrustEvaluator().evaluate(
            descriptor: descriptor,
            requirement: requirement(
                for: request,
                minimumLevel: minimumLevel,
                qualificationScope: qualificationScope
            ),
            health: health,
            artifactReader: artifactReader,
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
    ) -> RTLVerificationProcessEvidenceScope {
        RTLVerificationProcessEvidenceScope(
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
