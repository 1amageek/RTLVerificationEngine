# RTLVerificationEngine Goal Status

## Current state

**The declared native subset is executable, but the platform goal remains incomplete. M0 and the declared M1 frontend boundary are implemented; release qualification remains blocked until independent oracle, process and full flow evidence are attached.**

| Maturity gate | Status | Evidence |
|---|---|---|
| Responsibility boundary | Complete | README.md and DESIGN.md |
| Public package products | Implemented for current slice | Package.swift |
| Shared Xcircuite request/result contract | Implemented for current slice | Public Swift protocols, payloads and qualification gate |
| Contract build | Passed | `swift build` |
| Contract test | Passed | timeout-bounded SwiftPM test: 40 tests in 6 suites; qualification-input wiring, mapped pass/mismatch, persisted corpus runs, oracle evidence artifacts, freshness, scope binding and timeout fixtures included |
| Domain implementation | Complete for native subset | Native lint, CDC, RDC and structural equivalence backends |
| CLI implementation | Complete | `rtl-verify` deterministic JSON executable |
| Fixture corpus | Contract-complete smoke corpus | Retained positive/negative/equivalence/source-set fixtures, deterministic expectation evaluator and persisted corpus runner; independent corpus not attached |
| Oracle correlation | Artifact contract hardened, external evidence pending | `RTLVerificationOracleEvidenceBuilder` persists native/oracle envelopes and evidence JSON; matched correlation requires digest-bound artifacts and independent provenance; no external retained comparison evidence |
| Process qualification | Freshness contract hardened, process evidence pending | Process scope/record now requires a valid qualification window; no PDK-scoped qualification record |
| Xcircuite stage adapter | Implementation complete, LogicEngine bridge verified | `RTLVerificationFlowStageExecutor` persists result/qualification/review/audit artifacts; `LogicEquivalenceFlowStageExecutor` consumes synthesis requests and emits acceptance evidence |
| End-to-end flow evidence | Native LogicEngine synthesis → RTL mapped proof → acceptance verified | Retained Xcircuite evidence includes 5 LogicEngine adapter tests and 3 RTL stage/resume/qualification-gate tests; full workspace qualification remains open |
| Release readiness | Blocked | M1, M5, M6, M7 and M8 evidence are incomplete |

## Function status

| Function | Contract | Implementation | Validation corpus | Qualification |
|---|---|---|---|---|
| RTL lint | Contract + native backend | Implemented | Retained positive/negative fixtures | No process qualification |
| CDC analysis | Contract + native backend | Implemented | Retained positive/negative fixtures | No process qualification |
| RDC analysis | Contract + native backend | Implemented | Retained reset fixture | No process qualification |
| Formal equivalence | Contract + RTL/mapped structural backends | Implemented in declared scope | RTL mismatch, LogicDesignSnapshot lowering, mapped graph pass/mismatch, and counterexample fixtures | No solver/process qualification |
| Counterexample artifacts | Contract + JSON persistence | Implemented | Formal mismatch fixture | No process qualification |
| Waiver support | Scoped retained waivers | Implemented | Negative lint fixture | No process qualification |
| Coverage reporting | Typed coverage + blocked gate | Implemented | Parser/unsupported-path coverage | No process qualification |

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

- No external independent reference-oracle correlation artifact has been retained; the artifact-bound evidence contract and rejection paths are tested.
- No PDK/process-specific qualification record has been supplied; stale or missing freshness is rejected.
- The external adapter is contract-complete but requires a qualified command descriptor.
- The full Xcircuite test graph remains sensitive to unrelated workspace package changes; retained focused evidence covers the direct LogicEngine equivalence adapter path and RTL stage/resume/qualification gates. The Xcircuite package is intentionally not committed with this repository's focused changes because its worktree contains unrelated in-progress changes.
- The native frontend is a declared deterministic subset frontend with multi-file source sets, defines, conditionals, includes, include-cycle diagnostics and source provenance; complete IEEE SystemVerilog preprocessing/elaboration is not implemented.
- Native CDC consumes SDC clock declarations for coverage and unconstrained-clock findings; RDC reset intent and full exception semantics remain incomplete.
- Native formal is canonical RTL structural comparison plus the explicitly limited mapped LogicEngine graph comparison, not solver-backed temporal equivalence for synthesized or DFT views.
- The ToolQualification bridge declares RTL operation IDs and requirements, but no qualified descriptor, health result or process-scoped evidence is attached.
- Xcircuite review/audit/resume artifacts are implemented. Retained focused tests cover resume and LogicEngine acceptance; current source builds as an Xcircuite target, but the latest test graph is blocked outside RTL. Complete workspace-wide qualification remains open.

This file must be updated by implementation agents whenever a maturity gate changes. A source file or type name alone is never evidence of implementation or qualification.
