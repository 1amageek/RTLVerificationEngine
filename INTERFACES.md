# RTLVerificationEngine Interface Contract

## Common shape

```swift
public protocol DomainExecuting: Sendable {
    func execute(
        _ request: DomainRequest
    ) async throws -> XcircuiteEngineResultEnvelope<DomainPayload>
}
```

Requests carry a schema version, run ID, typed implementation/reference artifact sets, frontend policy and explicit proof/assumption scope. Payloads contain domain findings, coverage and qualification evidence. Diagnostics and artifacts belong to the shared envelope.

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
| `NativeCDCAnalyzer` | sequential clock inference, asynchronous crossings, synchronizer pattern recognition, reconvergence |
| `NativeRDCAnalyzer` | reset inference, reset domain mapping, missing/multiple reset events, reset crossings |
| `NativeFormalEquivalenceChecker` | exact RTL-to-RTL and mapped execution structural equivalence with machine-readable counterexamples |
| `ExternalRTLVerificationEngine` | same envelope contract for a process-qualified external command |

All native products consume `RTLVerificationParsedDesign`, whose design is the `LogicIR.RTLDesign` canonical state. `SystemVerilogRTLParser` supports ordered implementation and reference source sets, object-like defines, conditional compilation, quoted includes, source maps, declarations, continuous assignments, sequential/combinational processes, conditionals, instances, ranges, and expressions in its declared subset. Unsupported directives remain in coverage and can block the request.

`RTLVerificationQualificationEvaluator` is the deterministic qualification boundary. It advances state only when retained corpus evaluations, independent oracle correlations, process qualification and (for release) approval evidence satisfy their respective contracts.


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
