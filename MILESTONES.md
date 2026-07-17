# RTLVerificationEngine Milestones

`RTLVerificationEngine` is a verification platform boundary, not a parser demo. The implementation separates executable capability and raw evidence maturity from ToolQualification and release policy. A completed native execution is therefore not evidence of an accepted signoff backend.

## Delivery model

```mermaid
flowchart LR
    M0["M0 Contract integrity"] --> M1["M1 Frontend and provenance"]
    M1 --> M2["M2 Lint semantics"]
    M1 --> M3["M3 CDC/RDC constraints"]
    M1 --> M4["M4 Formal proof and CEX"]
    M2 --> M5["M5 Corpus and oracle"]
    M3 --> M5
    M4 --> M5
    M5 --> M6["M6 Tool/process trust handoff"]
    M6 --> M7["M7 Xcircuite resume and review"]
    M7 --> M8["M8 Release eligibility"]
```

## Milestone gates

| ID | Outcome | Entry criteria | Exit evidence | Current state |
|---|---|---|---|---|
| M0 | Contract integrity and explicit evidence maturity | Existing request/result protocols | Versioned evidence assessment, exact-schema validation, blocked diagnostics | Complete for schema v1 |
| M1 | Reproducible multi-file RTL frontend | M0 contracts | Preprocessor/elaboration policy, source map, stable entity IDs, language coverage matrix | Canonical SystemVerilogFrontend adapter includes top-module policy, source-set provenance, includes, deterministic object-like and function-like defines with nested arguments, bounded integer/comparison/logical `if` and `elsif` expressions, `ifdef`/`ifndef`/`else`, parameters, case statements, connected hierarchy flattening and generate blocks; malformed macros and unsupported conditional operators remain structured blockers and full IEEE elaboration is pending |
| M2 | Semantic lint useful for repair | M1 canonical design | Versioned rule catalog, positive/negative corpus, stable finding codes and suggested actions | Versioned native lint rule catalog and repair actions implemented; corpus/oracle qualification remains in progress |
| M3 | Constraint-aware CDC/RDC | M1 frontend and declared clocks/resets | SDC projection, clock/reset graph, synchronizer and reset-release evidence | CDC clock coverage and order-independent source-domain crossings implemented; RDC clock-domain blockers and conservative per-domain reset-release synchronizer evidence implemented; waveform/UPF reset intent and full exception semantics remain in progress |
| M4 | Proof boundary with counterexamples | M1 canonical views | RTL-to-RTL and mapped execution structural contracts, assumptions, qualified solver protocol, typed difference artifact schema | Native RTL-to-RTL and LogicEngine mapped execution boundaries complete with typed counterexample differences; external typed results bind descriptor identity/version and exact request digest; solver-backed completed proofs require a same-run digest-bound artifact; qualified temporal solver evidence pending |
| M5 | Independent validation | M2–M4 implementations | Retained corpus, expected findings, oracle correlation, false-positive/negative report | Persisted corpus runner, oracle-evidence builder, independent oracle executor, canonical request/payload binding, typed evidence input, artifact-bound oracle evidence contract and rejection paths complete; external oracle evidence pending |
| M6 | Process/tool trust handoff | M5 evidence | ToolQualification descriptor, health check, scope, freshness and PDK/deck evidence | RTL process-evidence contracts are available as raw observations; ToolQualification owns the trust decision and external PDK/process evidence remains pending |
| M7 | Headless flow and human review | M6 selection policy | Direct protocol composition in Xcircuite, immutable artifacts, resume/cancel, review bundle and approval gate | Outside this package; RTLVerificationEngine exposes direct protocols and immutable evidence for the composing flow |
| M8 | Release eligibility | M0–M7 complete | Release profile, audit packet, reproducible CLI/CI run, no unresolved blockers | External flow policy; not claimed by RTLVerificationEngine |

## Non-negotiable status rules

- `completed` means the requested executable operation returned without an execution error.
- `RTLVerificationEvidenceMaturity` is a separate observation axis carried in the result payload.
- ToolQualification decisions are injected for external-tool selection and are not derived from the result's evidence maturity.
- A structural native equivalence result is never promoted to temporal RTL-to-synthesized or synthesized-to-DFT proof.
- The `rtlToMappedExecutionStructural` view accepts a source LogicDesignSnapshot
  or LogicDesignDocument, lowers snapshots through LogicEngine, compares the
  canonical execution graph, and persists a counterexample on mismatch.
- Unsupported language, missing clock/reset declarations, missing assumptions, stale evidence, and absent process scope remain structured blockers.
- Domain waiver declarations are matched to original findings without changing severity; the composing flow owns acceptance and approval records.

## Evidence ledger required for M5–M8

```text
.xcircuite/
  runs/<run-id>/
    intent.json
    plan.json
    actions.jsonl
    design-diff.json
    verification/
      result.json
      report.json
      coverage.json
      evidence-assessment.json
      counterexamples/
    review/
      findings.json
      waivers.json
      approval.json
```

No milestone may be marked complete from a source declaration alone. The exit evidence must be retained, reproducible and linked to the exact implementation and input artifact digests.
