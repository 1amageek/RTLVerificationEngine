# RTLVerificationEngine Goal Status

## Current state

**The declared native subset is executable. M0 and the declared M1 frontend boundary are implemented, and the package emits retained corpus, oracle, and process observations. ToolQualification owns implementation trust; the composing flow owns release policy. Independent external oracle/process evidence and full-flow signoff remain platform work.**

| Maturity gate | Status | Evidence |
|---|---|---|
| Responsibility boundary | Complete | README.md and DESIGN.md |
| Public package products | Implemented for current slice | Package.swift |
| CircuiteFoundation execution/evidence boundary | Implemented for current slice | `RTLVerificationExecuting` refines `Engine`; `RTLVerificationResult` directly provides digest-bound artifacts, evidence, and structured diagnostics |
| Contract build | Passed | `swift build` |
| Contract test | Passed | timeout-bounded Xcode test: evidence-input binding, mapped pass/mismatch, typed counterexample differences, persisted corpus runs, oracle evidence artifacts, evidence-input artifact integrity auditing, canonical frontend coverage, retained process evidence binding, external descriptor/request identity, proof artifact byte integrity, concurrent stdout/stderr draining and process-tree timeout cleanup fixtures included |
| Domain implementation | Complete for native subset | Native lint, CDC, RDC and structural equivalence backends |
| CLI implementation | Complete | `rtl-verify` deterministic JSON executable |
| Fixture corpus | Contract-complete smoke corpus | Retained positive/negative/equivalence/source-set fixtures, deterministic expectation evaluator and persisted corpus runner; independent corpus not attached |
| Oracle correlation | Artifact and execution contract hardened, external evidence pending | `RTLVerificationOracleEvidenceBuilder` persists native/oracle envelopes and evidence JSON; `ExternalRTLVerificationOracleExecutor` enforces independent execution and payload digest correlation; matched evidence requires digest-bound artifacts and independent provenance; no external retained comparison evidence |
| Trust input observations | Retained artifact contract hardened, external process data pending | Corpus, oracle, health and implementation observations are digest-bound inputs for ToolQualification; no external PDK-scoped trust record is bundled |
| Flow composition boundary | Direct protocol consumption | RTLVerificationEngine remains standalone; flow consumers invoke `RTLVerificationExecuting` and own lifecycle/persistence |
| Release readiness | External policy | The composing flow requires accepted ToolQualification evidence, downstream signoff artifacts, and human approval |

## Function status

| Function | Contract | Implementation | Validation corpus | Qualification |
|---|---|---|---|---|
| RTL lint | Contract + native backend | Implemented | Retained positive/negative fixtures | No process qualification |
| CDC analysis | Contract + native backend | Implemented | Retained positive/negative fixtures | No process qualification |
| RDC analysis | Contract + native backend | Implemented for structural reset-release subset | Retained reset, unconstrained-clock, cross-domain and mixed-domain fixtures | No waveform/UPF/process qualification |
| Formal equivalence | Contract + RTL/mapped structural backends | Implemented in declared scope | RTL mismatch, LogicDesignSnapshot lowering, mapped graph pass/mismatch, typed counterexample fixtures and digest-bound external proof artifact gate | No actual temporal solver/process qualification |
| Counterexample artifacts | Contract + JSON persistence | Implemented | Formal mismatch fixture with typed difference records | No process qualification |
| Waiver support | Raw finding-to-waiver matches | Implemented | Negative lint fixture | Acceptance and approval remain flow-owned |
| Coverage reporting | Typed coverage + blocked gate | Implemented | Parser/unsupported-path coverage | No process qualification |
| Process evidence | Typed builder + retained artifact manifest | Implemented for observation scope | Valid build and missing/mismatched/unreferenced artifact fixtures | ToolQualification decision external |

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
ToolQualification trust evaluation
      ↓
flow-owned release policy
```

## Completion definition

The package goal is complete only when every P0 function has a concrete backend,
structured failure behavior, retained corpus, reference correlation where an
oracle exists, process-scoped observations where required, and a deterministic
standalone CLI/API contract. ToolQualification and cross-package release
integration are separate composing-package gates.

## Current blockers

- No external independent reference-oracle correlation artifact has been retained; the independent executor, exact payload binding and artifact-bound evidence contract are tested.
- No external PDK/process-specific evidence set has been supplied; the builder rejects incomplete scope, stale windows, missing/mismatched evidence and unreferenced artifacts, while a bare process record remains insufficient.
- The external engine is contract-complete but requires an eligible `ToolTrustDecision` from ToolQualification.
- The native frontend adapts the canonical LogicDesign SystemVerilog frontend for a declared deterministic subset with multi-file source sets, defines, `ifdef`/`ifndef`/`elsif`/`else` conditionals, includes, include-cycle diagnostics, source provenance, parameters, case statements, connected hierarchy flattening and generate blocks; complete IEEE SystemVerilog preprocessing/elaboration is not implemented.
- Native CDC consumes SDC clock declarations for coverage and unconstrained-clock findings and resolves module signal domains independent of process order; native RDC blocks unconstrained or unresolved reset-process clocks and recognizes a conservative multi-stage reset-release pattern per domain, while waveform/UPF reset intent and full exception semantics remain incomplete.
- Native formal is canonical RTL structural comparison plus the explicitly limited mapped LogicEngine graph comparison, not solver-backed temporal equivalence for synthesized or DFT views; mismatches persist typed difference records with canonical implementation/reference values. External execution rejects a completed solver-backed proof unless explicit proof IDs resolve to same-run output-role evidence/report artifacts whose bytes match their digest and byte count; actual temporal solver qualification remains open.
- The ToolQualification policy declares RTL operation IDs and requirements, but no accepted external descriptor, health result, or process-scoped evidence is attached.
- The Foundation boundary is implemented as a direct execution conformance and a loss-checked evidence projection. Flow lifecycle and concrete workspace persistence are owned by `DesignFlowKernel` and `Xcircuite`.

This file must be updated by implementation agents whenever a maturity gate changes. A source file or type name alone is never evidence of implementation or qualification.
