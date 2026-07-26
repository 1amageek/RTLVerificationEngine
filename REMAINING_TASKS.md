# RTLVerificationEngine Remaining Tasks

Updated: 2026-07-26

The declared native lint, CDC, RDC, and structural-equivalence subset is
executable. Remaining work covers independent evidence and semantic depth.

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| RTLV-1 | P1 | RTLVerificationEngine and oracle workflow | Retain an independent external reference-oracle correlation artifact. | Native and oracle executions use exact same-design payload binding, distinct implementation identity, verified proof/report bytes, immutable provenance, and deterministic matched/mismatched assessment. |
| RTLV-2 | P1 | Qualification workflow | Supply process- and PDK-scoped evidence and obtain an eligible ToolQualification decision for external execution. | Descriptor, health, corpus, oracle, process, PDK, and proof artifacts satisfy exact scope, freshness, integrity, and independence requirements. |
| RTLV-4 | P1 | RTLVerificationEngine and external solver adapter | Add solver-backed temporal equivalence for synthesized and DFT proof views. | Proof requests bind canonical implementation/reference artifacts, assumptions, solver identity, proof artifacts, counterexamples, timeout/cancellation, and independent qualification evidence. |
| RTLV-W1 | P2 | LogicDesign dependency | Broaden the canonical SystemVerilog frontend only through LogicDesign. | Required IEEE semantics are added to LogicDesign and consumed through its public snapshot contract; RTLVerificationEngine does not fork a second frontend. |

## External prerequisites

Flow lifecycle, persistence, waiver acceptance, human approval, and release
policy remain DesignFlowKernel/Xcircuite responsibilities.

RTLV-1 requires an independently retained oracle execution. RTLV-2 requires
process/PDK evidence and a ToolQualification decision. RTLV-4 requires an
actual temporal solver and its independent qualification evidence. The package
already owns and enforces the exact request, identity, artifact-integrity,
timeout and cancellation contracts for those external inputs.

## Completed P1

| ID | Completion evidence |
|---|---|
| RTLV-3 | Native RDC now requires paired digest-bound reset and canonical power intent for cross-domain completion; validates exact scope, polarity, assertion mode, release depth and non-overlapping power-domain element scopes; binds typed static/external exceptions; rejects SDC reset waivers; and retains positive/negative behavior tests. |

## Evidence reviewed

- `README.md`
- `DESIGN.md`
- `INTERFACES.md`
- `IMPLEMENTATION_PLAN.md`
- `MILESTONES.md`
- `GOAL_STATUS.md`, especially `Current blockers`
- `Sources` incomplete-implementation marker scan
