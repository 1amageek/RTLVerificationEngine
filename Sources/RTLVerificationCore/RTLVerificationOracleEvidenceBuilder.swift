import Foundation
import XcircuitePackage

public struct RTLVerificationOracleEvidenceBuilder: RTLVerificationOracleEvidenceBuilding {
    public let correlator: any RTLVerificationOracleCorrelating
    public let validator: RTLVerificationOracleEvidenceValidator
    public let writer: any RTLArtifactWriting

    public init(
        correlator: any RTLVerificationOracleCorrelating = RTLVerificationOracleCorrelator(),
        validator: RTLVerificationOracleEvidenceValidator = RTLVerificationOracleEvidenceValidator(),
        writer: any RTLArtifactWriting
    ) {
        self.correlator = correlator
        self.validator = validator
        self.writer = writer
    }

    public func build(
        caseID: String,
        requestDigest: String,
        native: XcircuiteEngineResultEnvelope<RTLVerificationPayload>,
        oracle: XcircuiteEngineResultEnvelope<RTLVerificationPayload>,
        oracleProvenance: String,
        runID: String
    ) async throws -> RTLVerificationOracleEvidenceBuildResult {
        guard Self.isSafeIdentifier(caseID) else {
            throw RTLVerificationExecutionError.invalidRequest(
                "Oracle case ID must contain only letters, numbers, '.', '_' or '-'."
            )
        }
        guard !requestDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest("Oracle request digest must not be empty.")
        }
        guard !oracleProvenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest("Oracle provenance must not be empty.")
        }
        guard !runID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RTLVerificationExecutionError.invalidRequest("Oracle run ID must not be empty.")
        }

        let report = correlator.correlate(caseID: caseID, native: native, oracle: oracle)
        let nativeArtifact = try await writer.persist(
            try Self.encode(native),
            artifactID: "oracle-\(caseID)-native",
            runID: runID
        )
        let oracleArtifact = try await writer.persist(
            try Self.encode(oracle),
            artifactID: "oracle-\(caseID)-result",
            runID: runID
        )
        let evidence = RTLVerificationOracleEvidence(
            evidenceID: "oracle-evidence:\(caseID)",
            caseID: caseID,
            requestDigest: requestDigest,
            nativeArtifact: nativeArtifact,
            oracleArtifact: oracleArtifact,
            report: report,
            oracleProvenance: oracleProvenance
        )
        let evidenceArtifact = try await writer.persist(
            try Self.encode(evidence),
            artifactID: "oracle-\(caseID)-evidence",
            runID: runID
        )
        if evidence.isAuditable {
            try validator.validate(evidence, expectedRequestDigest: requestDigest)
        }
        return RTLVerificationOracleEvidenceBuildResult(
            evidence: evidence,
            nativeArtifact: nativeArtifact,
            oracleArtifact: oracleArtifact,
            evidenceArtifact: evidenceArtifact
        )
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "." || character == "_" || character == "-"
        }
    }
}
