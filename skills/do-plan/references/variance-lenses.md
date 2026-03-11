# Variance Lenses

## Lens Vocabulary

| Lens | Domain | Focus directive | Example trigger |
|------|--------|----------------|----------------|
| `concurrency` | Parallel execution, race conditions, shared state | Surface locking, deadlock, and ordering risks; check shared mutable state | "async job", "parallel workers", "shared cache", "queue processing" |
| `migration` | Data migration, backward compat, rollback | Enumerate migration steps, rollback path, and dual-read/write windows | "migrate", "schema change", "upgrade", "legacy", "backward compat" |
| `api-surface` | Contract stability, versioning, consumer impact | Identify breaking changes, deprecation paths, and consumer blast radius | "public API", "endpoint", "SDK", "client contract", "versioning" |
| `security` | Auth boundaries, trust zones, secret handling | Map trust boundaries, privilege escalation paths, and secret exposure vectors | "auth", "permissions", "token", "secret", "validation", "access control" |
| `performance` | Hot paths, N+1, memory pressure | Measure cost on hot paths; flag N+1, allocation, and latency spikes | "cache", "slow query", "throughput", "memory", "performance" |
| `dependency` | Cross-module coupling, blast radius | Map coupling chains and transitive blast radius of the change | multi-file refactors, interface changes, shared utility edits |
| `ux-flow` | User-facing workflow impact, error messaging | Trace user journeys; surface friction, error clarity, and flow gaps | "UI", "form", "error message", "user flow", "onboarding", "feedback" |
| `data-model` | Schema shape, normalization, query patterns | Check normalization, index coverage, and query-pattern alignment | "schema", "model", "relation", "index", "query", "normalization" |
| `vertical-slice` | Feature builds, greenfield, PRD-driven work | Break implementation into thin end-to-end slices spanning all layers; each slice independently demoable. See [vertical-slices.md](vertical-slices.md) | "new feature", "greenfield", "PRD", "tracer bullet", "vertical slice", "from scratch", "build from zero" |

## Selection

Match task keywords against **Example trigger** column. Consider constraints and target files for implicit signals (e.g., touching auth middleware → `security`). When ambiguous, default to `dependency` for multi-file changes, `api-surface` for external callers.

## Dedup: do-plan

Drop a lens when its domain is fully covered by a default persona. Partial overlap → keep.

| Default persona | Overlapping lens |
|-----------------|-----------------|
| `thorough` planner | `concurrency` (when race conditions are the sole concern) |
| `conservative` planner | `migration` (when backward compat is the sole concern) |
| `counterpoint-dissenter` | `dependency` (when blast radius is the sole concern) |

## Dedup: do-execute

Drop a lens when its domain is fully covered by a default persona. Partial overlap → keep.

| Default persona | Overlapping lens |
|-----------------|-----------------|
| `correctness-reviewer` | `concurrency` (when race conditions are the sole concern) |
| `risk-reviewer` | `security`, `performance` |
