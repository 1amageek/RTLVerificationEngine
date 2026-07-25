# RTLVerificationEngine Remaining Tasks

Updated: 2026-07-26

The declared native lint, CDC, RDC, and structural-equivalence subset is
executable. Remaining work covers independent evidence and semantic depth.

## Remaining tasks

| ID | Priority | Owner | Task | Exit criteria |
|---|---|---|---|---|
| RTLV-1 | P1 | RTLVerificationEngine and oracle workflow | Retain an independent external reference-oracle correlation artifact. | Native and oracle executions use exact same-design payload binding, distinct implementation identity, verified proof/report bytes, immutable provenance, and deterministic matched/mismatched assessment. |
| RTLV-2 | P1 | Qualification workflow | Supply process- and PDK-scoped evidence and obtain an eligible ToolQualification decision for external execution. | Descriptor, health, corpus, oracle, process, PDK, and proof artifacts satisfy exact scope, freshness, integrity, and independence requirements. |
| RTLV-3 | P1 | RTLVerificationEngine | Complete RDC waveform/UPF reset intent and full exception semantics. | Reset-domain analysis has explicit temporal and power-intent semantics, typed constraint diagnostics, positive/negative retained fixtures, and no structural-only success claim for unsupported cases. |
| RTLV-4 | P1 | RTLVerificationEngine and external solver adapter | Add solver-backed temporal equivalence for synthesized and DFT proof views. | Proof requests bind canonical implementation/reference artifacts, assumptions, solver identity, proof artifacts, counterexamples, timeout/cancellation, and independent qualification evidence. |
| RTLV-W1 | P2 | LogicDesign dependency | Broaden the canonical SystemVerilog frontend only through LogicDesign. | Required IEEE semantics are added to LogicDesign and consumed through its public snapshot contract; RTLVerificationEngine does not fork a second frontend. |

## External prerequisites

Flow lifecycle, persistence, waiver acceptance, human approval, and release
policy remain DesignFlowKernel/Xcircuite responsibilities.

## Evidence reviewed

- `README.md`
- `DESIGN.md`
- `INTERFACES.md`
- `IMPLEMENTATION_PLAN.md`
- `MILESTONES.md`
- `GOAL_STATUS.md`, especially `Current blockers`
- `Sources` incomplete-implementation marker scan
