# RTLVerificationEngine Requirements

## Goal

Block structurally unsafe RTL and prove required equivalence relationships before physical implementation.

## Required functions

| Function | Required behavior | Priority |
|---|---|---:|
| RTL lint | Detect syntax-independent semantic, connectivity, width, state and coding hazards. | P0 |
| CDC analysis | Identify clock domains, synchronizers, unsafe crossings and reconvergence. | P0 |
| RDC analysis | Identify reset domains, reset sequencing and unsafe reset crossings. | P1 |
| Formal equivalence | Prove RTL-to-synthesized and synthesized-to-DFT equivalence under declared assumptions. | P0 |
| Counterexample artifacts | Persist machine-readable counterexamples and affected design entities. | P0 |
| Waiver support | Apply scoped, reviewable waivers without deleting findings. | P1 |
| Coverage reporting | Report analyzed and unsupported language, clock, reset and proof scope. | P0 |
| Frontend provenance | Record ordered input artifacts, digests, preprocessing decisions and top-module selection. | P0 |
| Proof-view contract | Distinguish RTL-to-RTL structural, RTL-to-synthesized and synthesized-to-DFT proof; block unsupported native claims. | P0 |
| Qualification evidence | Keep execution, corpus, oracle, process and release approval states distinct and auditable. | P0 |

## Required outcomes

- Unproven required equivalence blocks the flow.
- Every finding points to stable LogicDesign entities.
- Solver execution and proof scope are independently qualified.
- A retained corpus expectation is not an independent oracle; release eligibility requires the latter where an oracle exists.

## Common platform requirements

- Public execution surfaces are protocol-first, Sendable and dependency-injected.
- Requests and payloads are Codable, Hashable and schema-versioned.
- Inputs and outputs use immutable CircuiteFoundation `ArtifactReference` values.
- Diagnostics contain a stable code, severity, affected entity and suggested actions.
- Unsupported semantics and missing prerequisites produce blocked results.
- Native and external-tool backends conform to identical request and payload schemas.
- Execution capability, corpus validation, oracle correlation, process qualification and release approval remain distinct.
- Xcircuite owns flow construction, artifact persistence, qualification gates, repair loops, approval and resume.
- The package never imports Xcircuite or circuit-studio.

## Required developer surfaces

- Typed API
- Deterministic JSON CLI
- Positive and negative fixtures
- Contract and parser round-trip tests
- Reference corpus
- Capability and limitation report
- Xcircuite stage composition tests using direct protocol conformance
