# Vertical Slices

Tracer-bullet planning: thin end-to-end slices through ALL layers, not horizontal slices of one layer. Each slice independently demoable and verifiable.

## Principles

- Cut vertically through every layer (schema, API, UI, tests) — never one layer at a time
- Narrow but complete path: user action → all layers → observable result
- Many thin slices over few thick — smallest useful increment
- First slice is the tracer bullet: proves architecture, flushes integration risks
- Identify architectural anchors (durable decisions) before slicing — include in plan, exclude implementation details that change with later slices

## Slice Format

Per slice:
- **Title** — what the slice delivers
- **User stories** — which stories this slice covers (can be partial)
- **End-to-end behavior** — what to build through all layers
- **Acceptance criteria** — how to verify the slice works

## Anti-Patterns

- Planning one full layer before starting the next (horizontal slicing)
- Slices that can't be independently verified
- Including implementation details that will change with later slices
- Skipping the tracer bullet — going wide before going deep
