import Foundation

public struct RTLVerificationQualificationReport: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var implementationID: String
    public var implementationVersion: String
    public var state: RTLVerificationQualificationState
    public var evidence: [RTLVerificationQualificationEvidence]
    public var blockers: [String]
    public var limitations: [String]
    public var processQualification: RTLVerificationProcessQualificationRecord?

    public init(
        implementationID: String = "native-rtl-verification",
        implementationVersion: String = "1.0.0",
        state: RTLVerificationQualificationState = .unassessed,
        evidence: [RTLVerificationQualificationEvidence] = [],
        blockers: [String] = [
            "independent_corpus_validation_required",
            "oracle_correlation_required",
            "process_qualification_required"
        ],
        limitations: [String] = [],
        processQualification: RTLVerificationProcessQualificationRecord? = nil,
        schemaVersion: Int = RTLVerificationQualificationReport.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.implementationID = implementationID
        self.implementationVersion = implementationVersion
        self.state = state
        self.evidence = evidence
        self.blockers = blockers
        self.limitations = limitations
        self.processQualification = processQualification
    }

    public var isReleaseEligible: Bool {
        state == .releaseEligible && blockers.isEmpty && processQualification?.isQualified == true
    }

    public func satisfies(_ requiredState: RTLVerificationQualificationState) -> Bool {
        guard state >= requiredState else { return false }
        if requiredState == .unassessed {
            return true
        }
        guard blockers.isEmpty else { return false }
        if requiredState >= .processQualified,
           processQualification?.isQualified != true {
            return false
        }
        return requiredState < .releaseEligible || isReleaseEligible
    }

    public func with(
        state: RTLVerificationQualificationState,
        evidence: [RTLVerificationQualificationEvidence],
        blockers: [String],
        limitations: [String],
        processQualification: RTLVerificationProcessQualificationRecord? = nil
    ) -> RTLVerificationQualificationReport {
        RTLVerificationQualificationReport(
            implementationID: implementationID,
            implementationVersion: implementationVersion,
            state: state,
            evidence: evidence,
            blockers: blockers,
            limitations: limitations,
            processQualification: processQualification,
            schemaVersion: schemaVersion
        )
    }
}
