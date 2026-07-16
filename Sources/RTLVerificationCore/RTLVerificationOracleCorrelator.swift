import Foundation

public struct RTLVerificationOracleCorrelator: RTLVerificationOracleCorrelating {
    public init() {}

    public func correlate(
        caseID: String,
        native: RTLVerificationResult,
        oracle: RTLVerificationResult
    ) -> RTLVerificationOracleCorrelationReport {
        var mismatches: [RTLVerificationOracleCorrelationMismatch] = []
        let nativeImplementationID = native.provenance.producer.build
            ?? native.provenance.producer.identifier
        let oracleImplementationID = oracle.provenance.producer.build
            ?? oracle.provenance.producer.identifier
        let independenceVerified = nativeImplementationID != oracleImplementationID
        if !independenceVerified {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .oracleNotIndependent,
                expected: "different implementation IDs",
                observed: nativeImplementationID,
                message: "Native and oracle results use the same implementation ID."
            ))
        }
        if native.status != oracle.status {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .status,
                expected: oracle.status.rawValue,
                observed: native.status.rawValue,
                message: "Native and oracle execution statuses differ."
            ))
        }
        if native.payload.analysis != oracle.payload.analysis {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .analysis,
                expected: oracle.payload.analysis.rawValue,
                observed: native.payload.analysis.rawValue,
                message: "Native and oracle analysis kinds differ."
            ))
        }
        let nativeFindingCodes = Set(native.payload.findings.map(\.code))
        let oracleFindingCodes = Set(oracle.payload.findings.map(\.code))
        if nativeFindingCodes != oracleFindingCodes {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .findingCodes,
                expected: oracleFindingCodes.sorted().joined(separator: ","),
                observed: nativeFindingCodes.sorted().joined(separator: ","),
                message: "Native and oracle finding code sets differ."
            ))
        }
        if native.payload.proofStatus != oracle.payload.proofStatus {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .proofStatus,
                expected: oracle.payload.proofStatus ?? "nil",
                observed: native.payload.proofStatus ?? "nil",
                message: "Native and oracle proof statuses differ."
            ))
        }
        if native.payload.proofView != oracle.payload.proofView {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .proofView,
                expected: oracle.payload.proofView.rawValue,
                observed: native.payload.proofView.rawValue,
                message: "Native and oracle proof views differ."
            ))
        }
        if native.payload.coverage.unsupportedConstructs != oracle.payload.coverage.unsupportedConstructs
            || native.payload.coverage.analyzedConstructs != oracle.payload.coverage.analyzedConstructs {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .semanticCoverage,
                expected: "unsupported=\(oracle.payload.coverage.unsupportedConstructs.sorted()), analyzed=\(oracle.payload.coverage.analyzedConstructs)",
                observed: "unsupported=\(native.payload.coverage.unsupportedConstructs.sorted()), analyzed=\(native.payload.coverage.analyzedConstructs)",
                message: "Native and oracle semantic coverage differs."
            ))
        }
        let nativeSources = native.payload.coverage.sourceArtifacts.map { "\($0.path):\($0.sha256)" }
        let oracleSources = oracle.payload.coverage.sourceArtifacts.map { "\($0.path):\($0.sha256)" }
        if nativeSources != oracleSources {
            mismatches.append(RTLVerificationOracleCorrelationMismatch(
                kind: .sourceProvenance,
                expected: oracleSources.joined(separator: ","),
                observed: nativeSources.joined(separator: ","),
                message: "Native and oracle source provenance differs."
            ))
        }

        return RTLVerificationOracleCorrelationReport(
            caseID: caseID,
            nativeImplementationID: nativeImplementationID,
            oracleImplementationID: oracleImplementationID,
            nativeImplementationVersion: native.provenance.producer.version,
            oracleImplementationVersion: oracle.provenance.producer.version,
            independenceVerified: independenceVerified,
            matched: mismatches.isEmpty,
            mismatches: mismatches
        )
    }
}
