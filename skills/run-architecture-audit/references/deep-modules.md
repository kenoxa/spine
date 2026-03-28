# Deep Modules

A deep module has a simple interface hiding complex implementation. Depth ratio = implementation scope / export surface. Higher = deeper = better.

## Depth Heuristic

Shallow signals:
- Export count ~ implementation function count (thin wrapper)
- Pass-through functions that add no logic
- Callers must understand internals to use correctly
- Tests mock internal collaborators rather than boundary behavior

Deep signals:
- Few exports, large implementation behind them
- Callers need only interface knowledge
- Tests exercise boundary behavior, not internal wiring
- Error handling is internal — callers see clean failure modes

## Dependency Categories

| Category | Description | Test strategy | Deepening approach |
|----------|-------------|---------------|--------------------|
| In-process | Same runtime, direct call | Test through module boundary | Widen interface; absorb callers' orchestration logic |
| Local-substitutable | Same runtime, injected/swappable | Contract tests at interface | Extract port; hide implementation behind adapter |
| Remote-but-owned | Network boundary, you control both sides | Integration tests at port boundary | Ports & adapters — test port, stub adapter |
| True-external | Third-party, no control | Mock at boundary | Thin adapter wrapping external SDK; mock adapter in tests |

## Design It Twice

1. Generate 2+ radically different interfaces for the same module boundary
2. Compare on: simplicity, depth ratio, ease of correct use, error surface
3. Synthesize — best elements from each, not compromise between them
4. If all designs look similar, constraints are too narrow — widen the boundary

## Replace, Don't Layer

When deepening a module:
- Delete old shallow-module unit tests once boundary tests cover the behavior
- Test at the deepened module's interface boundary, not through old internal seams
- Never maintain parallel test suites for old and new structure

## Anti-Patterns

- Wrapping a shallow module in another shallow module (layering, not deepening)
- Refactoring internals without simplifying the interface
- Mocking in-process dependencies that should be absorbed
- Keeping pass-through functions "for backward compat"
- Testing the new boundary AND the old internals
