# RTLVerificationEngine Goal Status

## Current state

**The declared native subset is executable, but the platform goal remains incomplete. M0 and the declared M1 frontend boundary are implemented; release qualification remains blocked until independent oracle, process and full flow evidence are attached.**

| Maturity gate | Status | Evidence |
|---|---|---|
| Responsibility boundary | Complete | README.md and DESIGN.md |
| Public package products | Implemented for current slice | Package.swift |
| Shared Xcircuite request/result contract | Implemented for current slice | Public Swift protocols, payloads and qualification gate |
| Contract build | Passed | `swift build` |
| Contract test | Passed | timeout-bounded Xcode test: 75 tests in 8 suites; qualification-input health identity binding, mapped pass/mismatch, typed counterexample differences, persisted corpus runs, oracle evidence artifacts, qualification-input artifact integrity auditing, versioned lint rule catalog, canonical frontend parameterized hierarchy/case statements, function-like macro expansion, nested arguments, malformed invocation and recursion blocking, hierarchy flattening, conditional elsif selection, retained process evidence binding, order-independent CDC domains, conservative RDC reset-release synchronizer recognition, mixed-domain blockers, top policy, freshness, scope binding, external descriptor identity, exact request-digest binding, independent oracle execution, real external process/timeout behavior, process qualification artifact-manifest building, solver proof artifact binding and timeout fixtures included |
| Domain implementation | Complete for native subset | Native lint, CDC, RDC and structural equivalence backends |
| CLI implementation | Complete | `rtl-verify` deterministic JSON executable |
| Fixture corpus | Contract-complete smoke corpus | Retained positive/negative/equivalence/source-set fixtures, deterministic expectation evaluator and persisted corpus runner; independent corpus not attached |
| Oracle correlation | Artifact and execution contract hardened, external evidence pending | `RTLVerificationOracleEvidenceBuilder` persists native/oracle envelopes and evidence JSON; `ExternalRTLVerificationOracleExecutor` enforces independent execution and payload digest correlation; matched evidence requires digest-bound artifacts and independent provenance; no external retained comparison evidence |
| Process qualification | Retained evidence contract hardened, process evidence pending | `RTLVerificationProcessQualificationEvidenceBuilder` requires current PDK scope, request-bound independent oracle evidence, implementation-matched health evidence and a fully referenced digest/byte-count artifact manifest; no external PDK-scoped qualification record |
| Xcircuite stage adapter | Implementation complete, LogicEngine bridge verified | `RTLVerificationFlowStageExecutor` persists result/qualification/review/audit artifacts; `LogicEquivalenceFlowStageExecutor` consumes synthesis requests and emits acceptance evidence |
| End-to-end flow evidence | Native LogicEngine synthesis → RTL mapped proof → acceptance verified | Xcircuite serial full regression passes 550 tests in 59 suites, including the LogicEngine bridge, RTL stage/resume/qualification gates, independent oracle/process evidence flow, PDK corpus and end-to-end review contracts; full workspace qualification remains open |
| Release readiness | Blocked | M1, M5, M6, M7 and M8 evidence are incomplete |

## Function status

| Function | Contract | Implementation | Validation corpus | Qualification |
|---|---|---|---|---|
| RTL lint | Contract + native backend | Implemented | Retained positive/negative fixtures | No process qualification |
| CDC analysis | Contract + native backend | Implemented | Retained positive/negative fixtures | No process qualification |
| RDC analysis | Contract + native backend | Implemented for structural reset-release subset | Retained reset, unconstrained-clock, cross-domain and mixed-domain fixtures | No waveform/UPF/process qualification |
| Formal equivalence | Contract + RTL/mapped structural backends | Implemented in declared scope | RTL mismatch, LogicDesignSnapshot lowering, mapped graph pass/mismatch, typed counterexample fixtures and digest-bound external proof artifact gate | No actual temporal solver/process qualification |
| Counterexample artifacts | Contract + JSON persistence | Implemented | Formal mismatch fixture with typed difference records and legacy message compatibility | No process qualification |
| Waiver support | Scoped retained waivers | Implemented | Negative lint fixture | No process qualification |
| Coverage reporting | Typed coverage + blocked gate | Implemented | Parser/unsupported-path coverage | No process qualification |
| Process qualification evidence | Typed builder + retained artifact manifest | Implemented for contract scope | Valid build and missing/mismatched/unreferenced artifact fixtures | No external PDK/process qualification |

## Goal progression

```text
contract scaffold
      ↓
narrow implementation
      ↓
negative-path fixtures
      ↓
corpus validation
      ↓
reference-oracle correlation
      ↓
process-scoped qualification
      ↓
Xcircuite integration and repair loop
      ↓
release-profile eligibility
```

## Completion definition

The package goal is complete only when every P0 function has a concrete backend, structured failure behavior, retained corpus, reference correlation where an oracle exists, process-scoped qualification where required, a deterministic CLI and a passing Xcircuite headless integration test.

## Current blockers

- No external independent reference-oracle correlation artifact has been retained; the independent executor, exact payload binding and artifact-bound evidence contract are tested.
- No PDK/process-specific qualification record has been supplied; the builder now rejects incomplete scope, stale windows, missing/mismatched evidence and unreferenced artifacts, while a bare process record remains insufficient.
- The external adapter is contract-complete but requires a qualified command descriptor.
- The focused Xcircuite RTL flow suite currently passes 7 tests in 1 suite, including runtime qualification-input artifact integrity blocking before engine execution. The previously recorded Xcircuite serial full test graph passes 550 tests in 59 suites. A parallel run in the shared workspace produced transient cross-process failures, so it is not used as signoff evidence. The Xcircuite package is intentionally not committed with this repository's focused changes because its worktree contains unrelated in-progress changes.
- The native frontend adapts the canonical LogicDesign SystemVerilog frontend for a declared deterministic subset with multi-file source sets, defines, `ifdef`/`ifndef`/`elsif`/`else` conditionals, includes, include-cycle diagnostics, source provenance, parameters, case statements, connected hierarchy flattening and generate blocks; complete IEEE SystemVerilog preprocessing/elaboration is not implemented.
- Native CDC consumes SDC clock declarations for coverage and unconstrained-clock findings and resolves module signal domains independent of process order; native RDC blocks unconstrained or unresolved reset-process clocks and recognizes a conservative multi-stage reset-release pattern per domain, while waveform/UPF reset intent and full exception semantics remain incomplete.
- Native formal is canonical RTL structural comparison plus the explicitly limited mapped LogicEngine graph comparison, not solver-backed temporal equivalence for synthesized or DFT views; mismatches persist typed difference records with canonical implementation/reference values. The external adapter now rejects a completed solver-backed proof that lacks a same-run, digest-bound proof artifact; actual temporal solver qualification remains open.
- The ToolQualification bridge declares RTL operation IDs and requirements, but no qualified descriptor, health result or process-scoped evidence is attached.
- Xcircuite review/audit/resume artifacts are implemented. The current source builds as an Xcircuite target and the serial full graph passes; complete workspace-wide qualification and release evidence remain open.

This file must be updated by implementation agents whenever a maturity gate changes. A source file or type name alone is never evidence of implementation or qualification.
