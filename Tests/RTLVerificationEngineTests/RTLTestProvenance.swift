import CircuiteFoundation
import Foundation
import RTLVerificationCore

func makeRTLTestProvenance(
    engineID: String,
    implementationID: String,
    implementationVersion: String,
    startedAt: Date,
    completedAt: Date,
    seed: UInt64? = nil
) throws -> ExecutionProvenance {
    try ExecutionProvenance(
        producer: ProducerIdentity(
            kind: .engine,
            identifier: implementationID,
            version: implementationVersion,
            build: engineID
        ),
        invocation: ExecutionInvocation.inProcess(entryPoint: "RTLVerificationTests"),
        randomSeed: seed,
        startedAt: startedAt,
        completedAt: completedAt
    )
}

func replacingRTLTestProducer(
    in result: RTLVerificationResult,
    implementationID: String,
    implementationVersion: String
) throws -> RTLVerificationResult {
    try RTLVerificationResult(
        schemaVersion: result.schemaVersion,
        runID: result.runID,
        status: result.status,
        diagnostics: result.rtlDiagnostics,
        artifactBindings: result.artifactBindings,
        provenance: try makeRTLTestProvenance(
            engineID: result.provenance.producer.build
                ?? result.payload.analysis.stageID,
            implementationID: implementationID,
            implementationVersion: implementationVersion,
            startedAt: Date(
                timeIntervalSince1970: result.provenance.startedAt.secondsSinceUnixEpoch
            ),
            completedAt: Date(
                timeIntervalSince1970: result.provenance.completedAt.secondsSinceUnixEpoch
            ),
            seed: result.provenance.randomSeed
        ),
        payload: result.payload
    )
}
