# Orient Phase

Conditional — codebase-adjacent input only. Dispatch `@scout` + [orient-scout.md](orient-scout.md) + `@navigator` for breadth-first codebase context before Socratic dialogue. Clarify's no-subagent constraint does not apply here.

**Codebase-adjacency classification** (run at end of intake, after redirect check):

| Signal | Classification |
|--------|---------------|
| Upstream handoff (brainstorming or run-debug) | Codebase-adjacent — always orient |
| Names file, module, function, or component | Codebase-adjacent |
| Contains inline code block | Codebase-adjacent |
| Diagnostic language + named component | Codebase-adjacent (soft) |
| Diagnostic language only, no named component | Grounding question first; re-classify after |
| Design/architectural framing without operational context | Not codebase-adjacent — skip orient |
| Input < 1 sentence, grounding question not yet asked | Defer until after grounding response |
| Pure process/organizational/domain question | Not codebase-adjacent — skip orient |

**When codebase-adjacent**:
1. `@scout` + [orient-scout.md](orient-scout.md): intake signals as seed. Output: `.scratch/<session>/discuss-orient.md`
1b. `@navigator` + [navigator-synthesis.md](navigator-synthesis.md) parallel with scout. `seed_terms` from intake. Output: `.scratch/<session>/discuss-orient-external.md`
2. Artifacts must contain: Answer, File map, Gaps (note potential lens signals), External signals table
3. Session log: phase boundary, scout dispatched, 1-sentence summary. Carry `codebase_signals` + `external_signals` into clarify.

**When NOT codebase-adjacent**: skip to clarify. `codebase_signals = []`, `external_signals = []` unless research override triggers.

**External research override** (orient skipped, library names present):

| Signal | Action |
|--------|--------|
| Names library, framework, package, SDK | Dispatch `@navigator` standalone |
| References version constraint, API, "upstream" | Dispatch `@navigator` (soft) |
| No library/framework names | Skip — `external_signals = []` |
| Ambiguous | Dispatch — handles no-library gracefully |

When triggered: `@navigator` + [navigator-synthesis.md](navigator-synthesis.md) with `seed_terms`, `codebase_signals = []`. Output: `.scratch/<session>/discuss-orient-external.md`. Carry `external_signals` into clarify.

**Failure**: scout/navigator returns empty → signals = `[]`, note in Gaps, proceed. Re-run adjacency classification after grounding response if deferred.

Orient does NOT: select variance lenses (Investigate phase), ask user questions, block clarify.

> Anti-patterns: (1) Full @researcher at orient — orient = breadth with scout + navigator. (2) Asking user about codebase facts orient could answer. (3) Running orient on pure-domain problems.
