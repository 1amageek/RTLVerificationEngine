import Foundation

public struct RTLVerificationProcessEvidenceScope: Sendable, Hashable, Codable {
    public var implementationID: String
    public var binaryDigest: String
    public var algorithmVersion: String
    public var processProfileID: String
    public var pdkID: String
    public var pdkDigest: String
    public var deckDigest: String
    public var solverID: String?
    public var solverVersion: String?
    public var analyses: [RTLVerificationAnalysis]
    public var proofViews: [RTLVerificationProofView]

    public init(
        implementationID: String,
        binaryDigest: String,
        algorithmVersion: String,
        processProfileID: String,
        pdkID: String,
        pdkDigest: String,
        deckDigest: String,
        solverID: String? = nil,
        solverVersion: String? = nil,
        analyses: [RTLVerificationAnalysis],
        proofViews: [RTLVerificationProofView] = []
    ) {
        self.implementationID = implementationID
        self.binaryDigest = binaryDigest
        self.algorithmVersion = algorithmVersion
        self.processProfileID = processProfileID
        self.pdkID = pdkID
        self.pdkDigest = pdkDigest
        self.deckDigest = deckDigest
        self.solverID = solverID
        self.solverVersion = solverVersion
        self.analyses = analyses
        self.proofViews = proofViews
    }

    public var isComplete: Bool {
        let requiredValues = [
            implementationID,
            binaryDigest,
            algorithmVersion,
            processProfileID,
            pdkID,
            pdkDigest,
            deckDigest
        ]
        guard requiredValues.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return false
        }
        guard !analyses.isEmpty else { return false }
        if analyses.contains(.formalEquivalence) {
            guard let solverID, let solverVersion,
                  !solverID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !solverVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !proofViews.isEmpty else {
                return false
            }
        }
        return true
    }
}
