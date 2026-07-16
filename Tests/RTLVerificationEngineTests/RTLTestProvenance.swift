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
            identifier: engineID,
            version: implementationVersion,
            build: implementationID
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
    RTLVerificationResult(
        schemaVersion: result.schemaVersion,
        runID: result.runID,
        status: result.status,
        diagnostics: result.rtlDiagnostics,
        artifacts: result.artifacts,
        provenance: try makeRTLTestProvenance(
            engineID: result.provenance.producer.identifier,
            implementationID: implementationID,
            implementationVersion: implementationVersion,
            startedAt: result.provenance.startedAt,
            completedAt: result.provenance.completedAt,
            seed: result.provenance.randomSeed
        ),
        payload: result.payload
    )
}
