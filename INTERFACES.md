# RTLVerificationEngine Interface Contract

## Common shape

```swift
public protocol DomainExecuting: Sendable {
    func execute(
        _ request: DomainRequest
    ) async throws -> XcircuiteEngineResultEnvelope<DomainPayload>
}
```

Requests carry a schema version, run ID, typed implementation/reference artifact sets, frontend policy, explicit proof/assumption scope and an optional retained qualification input. Payloads contain domain findings, coverage and qualification evidence. Diagnostics and artifacts belong to the shared envelope. The CLI loads the same qualification input through `--qualification-input` so headless and library execution share one gate.

`RTLVerificationCorpusRunner` executes a deterministic, uniquely identified set of corpus cases through the same engine protocol, persists each result envelope and writes a digest-bound aggregate `RTLVerificationCorpusRun` under the supplied run ID. A corpus run is matched only when every case expectation is satisfied; execution errors are thrown rather than converted into qualification evidence.

`RTLVerificationOracleEvidenceBuilder` persists native and independent-oracle result envelopes plus an evidence JSON artifact, correlates their typed payloads, and returns `RTLVerificationOracleEvidenceBuildResult`. A mismatched correlation is retained as a non-auditable result so qualification remains blocked while the failure is reviewable.

`RTLVerificationLintRuleCatalog` is the versioned repair contract for native lint findings. Each rule declares a stable code, severity, description and suggested actions; a catalog entry does not waive the finding or advance qualification.

## Products

### RTLLint

Typed RTL diagnostics.

### CDCAnalysis

Clock-domain crossing analysis.

### RDCAnalysis

Reset-domain crossing analysis.

### FormalEquivalence

RTL-to-netlist proof and counterexamples.

### RTLVerificationEngine

Umbrella API.

### Native and external implementations

| Type | Scope |
|---|---|
| `NativeRTLLintEngine` | symbol resolution, width checks, driver checks, sequential assignment checks, combinational loops, undriven outputs |
| `NativeCDCAnalyzer` | sequential clock inference, order-independent source-domain crossings, asynchronous crossings, synchronizer pattern recognition, reconvergence |
| `NativeRDCAnalyzer` | reset inference, reset domain mapping, missing/multiple reset events, reset crossings |
| `NativeFormalEquivalenceChecker` | exact RTL-to-RTL and mapped execution structural equivalence with machine-readable counterexamples |
| `ExternalRTLVerificationEngine` | same envelope contract for a process-qualified external command |

All native products consume `RTLVerificationParsedDesign`, whose design is the `LogicIR.RTLDesign` canonical state. `SystemVerilogRTLParser` adapts `SystemVerilogFrontend`, expands constant generate blocks and flattens connected top-level hierarchy through `RTLHierarchyElaborator`. It supports ordered implementation and reference source sets, object-like defines, conditional compilation, quoted includes, source maps, parameters, declarations, continuous assignments, sequential/combinational/latch processes, conditionals, case statements, instances, ranges, hierarchy and generate blocks in its declared subset. Unsupported directives and hierarchy forms remain in coverage or typed blocked diagnostics.

`RTLVerificationQualificationEvaluator` is the deterministic qualification boundary. It advances state only when retained corpus evaluations, independent oracle correlations, process qualification and (for release) approval evidence satisfy their respective contracts.

`RTLVerificationOracleCorrelationReport` is a comparison result, not qualification evidence by itself. `RTLVerificationOracleEvidence` must bind the report to the request digest, digest-bearing native and oracle result artifacts, and explicit independent provenance. `RTLVerificationOracleEvidenceValidator` rejects missing bindings or self-correlation. Process qualification records likewise require a complete process scope and a valid `qualifiedAt`/`expiresAt` window at evaluation time.

External process descriptors carry a finite `timeoutSeconds` value. Runners that conform to `RTLExternalToolProcessRunningWithTimeout` receive that deadline; the Foundation runner terminates a process that exceeds it and returns a typed external-tool failure. Legacy runners remain supported through the original protocol method.

The mapped execution proof view is intentionally explicit:

```mermaid
flowchart LR
  SourceRef["source LogicDesignSnapshot / LogicDesignDocument"] --> Lower["NativeLogicDesignLowering when needed"]
  Lower --> SourceGraph["canonical source execution graph"]
  MappedRef["mapped LogicDesignDocument"] --> MappedGraph["canonical mapped execution graph"]
  SourceGraph --> Compare["mapped execution structural comparator"]
  MappedGraph --> Compare
  Compare --> Report["proof report + counterexample"]
```

This view ignores mapping-only cell labels and node identifiers, but does not
claim temporal sequential equivalence, analog behavior, or foundry/process
qualification.


## Error contract

- Throw only when execution cannot produce a valid result envelope.
- Represent design findings and failed checks as typed diagnostics and a completed domain payload.
- Represent missing prerequisites or insufficient semantics as `blocked`.
- Preserve cancellation as `cancelled`.
- Do not swallow parser, process or persistence failures.

## Xcircuite adapter

The adapter must:

1. resolve project-relative references through XcircuitePackage;
2. verify input digests;
3. evaluate ToolQualification requirements;
4. invoke the injected engine protocol;
5. persist every returned artifact;
6. map diagnostics and status to FlowStageResult;
7. attach design, PDK and tool provenance;
8. persist qualification, review and audit artifacts;
9. resume only when the persisted audit identity and request digest match.

`Xcircuite` provides `RTLVerificationFlowStageExecutor`, which resolves `XcircuiteFlowInputReference`, verifies digest-bearing file references, invokes the injected or native engine, persists the envelope plus qualification/review/audit artifacts, and maps the result to `FlowStageResult` and a gate.
