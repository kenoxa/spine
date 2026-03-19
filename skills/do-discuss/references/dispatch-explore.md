# Explore Phase

Multi-perspective exploration. Scales dispatch to scope ambiguity and `key_decisions` complexity; zero-dispatch (phase executes, dispatches no subagents) when scope is converged and key decisions resolved or deferred. Zero-dispatch: log Phase Trace row: `| Explore | zero-dispatch | — | [rationale] |` Three `@framer` personas for one-way-door decisions resisting convergence:

| Role | Reference | Output |
|------|-----------|--------|
| `stakeholder-advocate` | `explore-stakeholder-advocate.md` | `.scratch/<session>/discuss-explore-stakeholder-advocate.md` |
| `systems-thinker` | `explore-systems-thinker.md` | `.scratch/<session>/discuss-explore-systems-thinker.md` |
| `skeptic` | `explore-skeptic.md` | `.scratch/<session>/discuss-explore-skeptic.md` |

Concurrent with framers:
- `@navigator` + `run-explore/references/explore-alternatives.md` → `.scratch/<session>/discuss-explore-navigator.md`
- `@envoy` (via `use-envoy`) → `.scratch/<session>/discuss-explore-envoy.md`. Tier: standard. Not re-dispatched for peer-reaction (single-pass CLI). Output feeds Frame synthesis as peer input. Prompt: `problem_frame` + `known`/`unknown` + `key_decisions` + `codebase_signals` + `external_signals` (self-contained).

All dispatches parallel → wait → re-invoke framers + navigator to read peers + append `## Peer Reactions` → synthesize. Irreconcilable positions → `key_decisions`. Augmented `@framer` + `explore-augmented-framer.md` with variance lens from investigate (or select per `do-plan/references/variance-lenses.md`). Output: `.scratch/<session>/discuss-explore-augmented-{lens}.md`. Included in peer reaction.

Cap: base framers (3) + navigator (1) + envoy (1) + augmented <= 6.

> Anti-patterns: (1) Full framer team for simple problems with no one-way-door decisions. (2) Re-dispatching navigator for already-covered dependency.
