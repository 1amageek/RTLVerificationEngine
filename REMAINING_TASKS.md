# RTLVerificationEngine Remaining Tasks

Updated: 2026-07-26

The declared native lint, CDC, RDC, and structural-equivalence subset is
executable. Remaining work covers independent evidence and semantic depth.

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| RTLV-W1 | P2 | LogicDesign dependency | Broaden the canonical SystemVerilog frontend only through LogicDesign. | Required IEEE semantics are added to LogicDesign and consumed through its public snapshot contract; RTLVerificationEngine does not fork a second frontend. |

## External prerequisites

Flow lifecycle, persistence, waiver acceptance, human approval, and release
policy remain DesignFlowKernel/Xcircuite responsibilities.

RTLV-1 requires an independently retained oracle execution. RTLV-2 requires
process/PDK evidence and a ToolQualification decision. RTLV-4 requires an
actual temporal solver and its independent qualification evidence. The package
already owns and enforces the exact request, identity, artifact-integrity,
timeout and cancellation contracts for those external inputs.

| Former ID | Owner | Required evidence |
|---|---|---|
| RTLV-1 | Independent oracle workflow | Same-design native/oracle executions with distinct implementation identity, verified proof/report bytes, immutable provenance, and deterministic correlation. |
| RTLV-2 | Qualification workflow | Process/PDK-scoped descriptor, health, corpus, oracle, proof, freshness, integrity, and independence evidence producing an eligible ToolQualification decision. |
| RTLV-4 | Temporal solver provider and qualification workflow | An actual synthesized/DFT temporal solver retaining canonical request bindings, assumptions, proof/counterexample artifacts, timeout/cancellation behavior, identity, and independent qualification evidence. |

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
