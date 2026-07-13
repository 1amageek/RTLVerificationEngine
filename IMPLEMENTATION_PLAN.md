# RTLVerificationEngine Implementation Plan

## Order

The work is intentionally staged around trust boundaries. The first implementation slice is not considered the product endpoint.

1. Contract integrity and explicit qualification state (M0)
2. Multi-file frontend, preprocessing policy, elaboration and provenance (M1)
3. Versioned lint semantics and repair diagnostics (M2)
4. Constraint-aware CDC/RDC graphs (M3)
5. RTL-to-gate/DFT proof views, assumptions and counterexamples (M4)
6. Independent corpus and oracle correlation (M5)
7. ToolQualification and process-scoped release gates (M6)
8. Xcircuite artifact ledger, review, resume and approval loop (M7)
9. Reproducible release profile and audit packet (M8)

## Implemented native slice

- Shared typed request, payload, finding, waiver, coverage, report and capability contracts.
- Canonical `SystemVerilogFrontend` adapter into `LogicIR.RTLDesign`, with deterministic source-set preprocessing and provenance mapping.
- Multi-file implementation and reference source sets with deterministic defines, conditional compilation, include resolution, include-cycle diagnostics and source provenance.
- Native lint, CDC, RDC, RTL structural equivalence and mapped LogicEngine execution-graph equivalence backends.
- Counterexample artifact persistence through the injected artifact writer.
- Positive/negative retained fixtures, source-set formal fixtures, mapped graph pass/mismatch fixtures, corpus expectation evaluation and oracle-correlation tests.
- Deterministic `rtl-verify` CLI with repeated RTL/reference inputs, SDC, frontend policy and `--qualification-input` artifact loading.
- Xcircuite `RTLVerificationFlowStageExecutor` with input digest verification, review/audit persistence and resumable stage-result mapping.
- Qualification state, evidence and minimum-policy gates are part of the public result contract. Native execution remains unassessed until independent evidence is attached.

## Qualification slice still required

- Execute and retain native/external results against an independently retained reference oracle; the typed correlator, persisted oracle-evidence builder, artifact-bound evidence record and independence guard are implemented, but external evidence is not supplied.
- Record process-specific qualification evidence for every supported PDK and solver configuration; the process scope/record now enforces freshness and the ToolQualification bridge is implemented, but no PDK evidence is supplied.
- Add those evidence records to ToolQualification before release eligibility is granted.
- Enforce bounded external process execution and retain timeout failures as structured diagnostics.
- Extend the declared frontend boundary toward complete SystemVerilog preprocessing/elaboration and publish the language coverage matrix; the current adapter covers parameters, case statements, hierarchy and generate blocks in the declared subset.
- Project SDC clocks and timing exceptions into CDC/RDC analysis instead of treating `constraints` as an unused request field.
- Add proof-view identity, assumptions and trace semantics for RTL-to-synthesized and synthesized-to-DFT equivalence.
- Extend the persisted corpus-run artifact pattern to oracle, qualification and release evidence, then connect those immutable artifacts to the Xcircuite audit packet. Corpus result envelopes and the aggregate `RTLVerificationCorpusRun` are now persisted by the native runner.

## Completion gates

- Public APIs remain protocol-first and Sendable.
- Every unsupported semantic produces a structured blocked result.
- Native and external backends produce the same result schema.
- No UI type enters a public contract.
- No result claims foundry qualification without process-scoped oracle evidence.
- Xcircuite can execute, persist, review and resume the stage without circuit-studio once the workspace-wide dependency compile is green.
