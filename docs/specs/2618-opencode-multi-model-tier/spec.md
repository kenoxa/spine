---
id: 2618-opencode-multi-model-tier
status: approved
updated: 2026-04-27
frame_artifact: .scratch/opencode-models-tier-frame-97c5/frame-artifact.md
design_artifact: .scratch/opencode-models-tier-frame-97c5/design-artifact.md
session_id: opencode-models-tier-frame-97c5
---

# OpenCode Multi-Model Tier Re-selection

## Goal

(1) Re-select OpenCode-Go tier model picks against the April 2026 model lineup using quality-per-role as the sole criterion. (2) Add multi-model-per-tier dispatch to envoy — within OpenCode, one tier resolves to N models that run in parallel, all outputs feeding the existing synthesizer. Multi-model is open across all tiers; whether a tier ships single-model or multi-model is decided per-tier on quality grounds.

## Why

The existing tier-to-model mapping (`Frontier=mimo-v2-pro / Standard=minimax-m2.7 / Fast=minimax-m2.5`) was selected before the April 2026 model wave. Eight new/refreshed Go-roster models — verified by E3 local probe and the official Go page screenshot dated 2026-04-27 — score above the current picks on the benchmarks each tier was selected for: SWE-V, SWE-P, TB2 (Terminal-Bench 2.0), LCB (LiveCodeBench v6), Code Arena Elo. Envoy's OpenCode dispatch path is also structurally locked to a single model per tier (`skills/use-envoy/scripts/_common.sh:71-86` returns one slug per `tier:provider`), so even a council-diverse model set cannot fan out within OpenCode the way it fans out across providers in `--mode multi`. Both gaps are addressed in one spec because both touch `resolve_tier()`; otherwise the changes are independent and ship as separate slices.

## Scope

### In

- New tier model picks (Go subscription only). Free-tier picks (`opencode/qwen3.6-plus-free`, `opencode/minimax-m2.5-free`, `opencode/mimo-v2-pro-free`) untouched.
- `resolve_tier()` returns a structured object `{primary, fanout[], effort}` so `install.sh` (single-string consumer) and runtime (fan-out list consumer) share one source of truth.
- Parallel multi-model dispatch within OpenCode using per-process `XDG_DATA_HOME` isolation, staggered worker startup, and per-worker wall-clock timeout.
- Synthesizer adapter: per-model output files at `<base>.opencode.<slug>.md`. Existing `<base>.<provider>.md` glob extends additively.
- Provider success semantics: ≥1 worker succeeded = success.
- N=1 / N≥1 share one dispatch codepath (list semantics; N=1 is a one-element list). No special-case branch.
- Documentation sync across `docs/model-selection.md`, `docs/model-tier-assignments.md`, `docs/multi-model-council-sizing.md`, `env.example`, and the stale `project_opencode_provider.md` memory entry.
- Verifier spike (concurrency stress test under `XDG_DATA_HOME` isolation) before parallel dispatch ships default-on.

### Out (this slice)

- Tier renaming (`Frontier/Standard/Fast` → `gate/implement/recon`) — single-source advocacy in advisory; deferred.
- Free-tier model re-selection.
- Cross-provider intra-tier multi-model (e.g., multi-model within Claude or Codex) — only OpenCode in this spec.
- Direct OpenCode HTTP API path (currently `opencode run` CLI only).
- Hook-driven quota probing or pre-flight rate-limit checks.

## Tier picks (resolved decisions)

Quality-first per role; usage limits explicitly excluded from selection criteria (user instruction 2026-04-27).

| Tier | Models | Selection rationale |
|------|--------|---------------------|
| **Frontier** (gate authority — consultant, inspector, verifier, synthesizer) | `mimo-v2.5-pro` + `deepseek-v4-pro` + `kimi-k2.6` | Top three coding-benchmark leaders in the roster. Three labs (Xiaomi / DeepSeek / Moonshot). MiMo: TB2 leader (68.4), 1M context, harness-aware long-horizon. DeepSeek V4 Pro: SWE-V #1 (80.6), LCB #1 (93.5), Codeforces #1, competitive-programming + math heritage. Kimi K2.6: SWE-V 80.2, SWE-P #1 among open-weights (58.6), TB2 66.7, 300-agent swarm-trained long-horizon. **Accepted trade-off**: K2.6 + MiMo share Cluster B failure mode (long-horizon agentic specialists); quality wins over diversity-when-they-conflict. |
| **Standard** (implementation — implementer, analyst) | `qwen3.6-plus` + `glm-5.1` | Two labs (Alibaba / Z.AI-Tsinghua) distinct from Frontier — preserves implementation-vs-gate separation. Qwen3.6 Plus: SWE-V 78.8 (#2 in roster), TB2 61.6, 1M context, always-on chain-of-thought. GLM-5.1: SWE-P 58.4 (#1 globally), Code Arena Elo 1530 (#3 globally), 203K context. GLM's HLE 31% reasoning weakness is irrelevant for code implementation. |
| **Fast** (recon/extraction — scout, runner) | `deepseek-v4-flash` (single) | 1M context, architecturally fast (13B active params), latency-optimized. Single-model: extraction doesn't synthesize. |

Replaces: `mimo-v2-pro`, `minimax-m2.7`, `minimax-m2.5`.

## Key design constraints

| # | level | constraint | source |
|---|-------|-----------|--------|
| C1 | MUST | Multi-model fan-out uses per-process `XDG_DATA_HOME` isolation. Shared `~/.local/share/opencode/opencode.db` has `PRAGMA busy_timeout=0` and silently swallows `SQLITE_BUSY`. | navigator E1 (issues #21215, #15188), envoy-codex E3 local probe |
| C2 | MUST | Provider success = ≥1 worker succeeded. Non-zero only when all workers fail. | universal across advisory sources |
| C3 | MUST | Per-worker wall-clock timeout (default 10 min, env-overridable). `opencode run` can hang indefinitely on some provider/model combos. | navigator E1 (issue #17516) |
| C4 | MUST | Output naming `<base>.opencode.<slug>.md`. Aggregated single-file rejected. | all six advisory sources converge |
| C5 | MUST | N=1 and N≥1 share one dispatch codepath (list semantics). | five-of-six sources; codebase precedent at `run.sh:159-167`, `run.sh:111` |
| C6 | MUST | Re-selection picks locked against live `opencode models opencode-go` at install time, not against external docs. | envoy-codex E3 |
| C7 | SHOULD | Staggered worker startup (~250ms) on top of XDG isolation. | navigator (`oc_py_wrapper` reference impl) |
| C8 | SHOULD | Re-selection and multi-model ship as separate slices. | rigorous + envoy-cursor pragmatic middle path |
| C9 | SHOULD | `resolve_tier()` returns `{primary, fanout[], effort}`. | envoy-codex (architecturally strongest) |

Full constraint set in the design artifact.

## Success criteria (EARS)

1. **SC1** — When envoy resolves an OpenCode tier with multiple configured models, the system shall invoke all models in parallel and emit one output per model under `.scratch/<session>/`.
2. **SC2** — When envoy resolves an OpenCode tier with a single configured model, the system shall behave identically to today's single-slug dispatch — no behavioral regression.
3. **SC3** — When one model in a multi-model tier fails (quota, timeout, error), the synthesizer shall still receive the successful outputs from the remaining models without aborting the round.
4. **SC4** — When the new tier mapping is documented, the docs (`model-selection.md`, `model-tier-assignments.md`) and the runtime (`_common.sh`, `install.sh`, `invoke-opencode.sh`) shall match — no drift across the configuration touchpoints.
5. **SC5** — If `XDG_DATA_HOME` isolation proves insufficient (e.g., file-watcher state bleed per issue #4251), the design shall fall back to serialized dispatch within the same tier-list contract — no API change to consumers.
6. **SC6** — On install, picks are validated against `opencode models opencode-go` output; mismatched slugs fail loudly.

## Delivery slices

### Slice 1 — Re-selection (single-model upgrades)

Update `resolve_tier()` Go-tier outputs and `install.sh` model mapping. Sync docs. No architectural change. Ships independently.

- Frontier=`mimo-v2.5-pro`, Standard=`qwen3.6-plus`, Fast=`deepseek-v4-flash`. Single-model picks at every tier (multi-model triples/pairs come in slice 3).
- Entry: `opencode models opencode-go` returns the three picks (E3 build-time probe).
- Exit: envoy invocation at each tier produces correct provider+model in output files; doc grep shows zero references to retired models at the OpenCode-Go tier mappings.
- Size: ~30 LOC bash + ~60 LOC docs.

### Slice 2 — Verifier spike (concurrency check)

Standalone script under `.scratch/opencode-models-tier-frame-97c5/verify-opencode-concurrency.sh`. Spawns 3 parallel `opencode run` workers, each with its own `XDG_DATA_HOME`, on a trivial prompt. Measures: (a) all 3 produce non-empty stdout, (b) wall-clock ≤ 1.3× single-worker baseline, (c) no `SQLITE_BUSY` symptoms, (d) no file-watcher cross-contamination (issue #4251).

- Entry: Slice 1 merged.
- Exit: Pass/fail measured. Determines slice 3 default-on vs default-off posture for parallel dispatch.
- Size: ~80 LOC bash, `.scratch/`-only, no production touch.

### Slice 3 — Multi-model dispatch architecture

- Restructure `resolve_tier()` to return `{primary, fanout[], effort}` (`_common.sh`).
- Extract `invoke-opencode-one.sh` (single-worker) from existing `invoke-opencode.sh`. Rewrite `invoke-opencode.sh` as orchestrator: `XDG_DATA_HOME` setup, staggered startup, parallel wait, partial-failure handling.
- Extend `run.sh` glob to `<base>.opencode*.md`; change OpenCode provider success semantics to "≥1 worker succeeded".
- Update `install.sh` to consume `.primary` for agent frontmatter.
- Wire Frontier triple (`mimo-v2.5-pro` + `deepseek-v4-pro` + `kimi-k2.6`) and Standard pair (`qwen3.6-plus` + `glm-5.1`) as default `fanout[]`. Fast stays N=1 (`deepseek-v4-flash`).
- Update `env.example` with multi-model override syntax. Update `docs/model-selection.md` (multi-model semantics section), `docs/multi-model-council-sizing.md` (cross-link), `docs/cross-provider-hooks.md` if relevant.
- Entry: Slice 2 verifier passed.
- Exit: Frontier envoy call produces 3 output files; synthesizer ingests all 3; partial-failure injection (kill one worker mid-run) leaves the round successful with 2 outputs; latency stays within verifier-measured budget.
- Size: ~400-500 LOC bash + ~100 LOC docs.

## Open questions

1. Should Frontier triple ship enabled by default, or behind an env flag at first rollout? Verifier results decide.
2. Synthesis context-window pressure when multi-provider council × multi-model OpenCode produces up to 12 input files in one synthesis pass (3-model OpenCode triple × 4-provider cross-council). If quality drops: cap intra-OpenCode at 2, or add per-provider pre-summary step.
3. Whether the Standard pair runs multi-model dispatch or stays single-model in slice 3's first rollout. Verifier spike applies equally.

## Rejected

- **Aggregated single-file output `<base>.opencode.md` with internal sections** — conflates partial-success vs all-success; loses "missing file = source failed" detection; new schema required for synthesizer.
- **Separate config file (`skills/use-envoy/models.conf`)** — adds 8th touchpoint and parser dependency; structured tier object inside `_common.sh` covers same need without new file.
- **Tier rename `Frontier/Standard/Fast` → `gate/implement/recon`** — single-source advocacy (creative angle only); scope creep; tier names persist as roles.
- **In-process backgrounding of `opencode_invoke` calls (same shell, `&`-jobs sharing globals)** — `_json_tmp`, `_rc`, `_meta_*` globals would race even before OpenCode's own DB state hits.
- **`opencode serve` + multiple `attach` clients** — couples all parallel dispatches to one server process; per-process `XDG_DATA_HOME` gives fault isolation.
- **Frontier triple `MiMo + GLM-5.1 + DeepSeek V4 Pro`** — GLM+MiMo overlap on "reasoning-weak coding specialist" failure mode (research-models.md Cluster A); rejected hardware-lineage as the diversity justification.
- **Frontier triple `MiMo + DeepSeek + Qwen3.6`** — Qwen3.6 trails K2.6 on SWE-V, SWE-P, and TB2; user prioritized quality over diversity-when-they-conflict. (Remains the diversity-first alternative if Cluster B overlap of K2.6+MiMo causes problems in production.)
- **Single-model Frontier (`mimo-v2.5-pro` only)** — frame-artifact constraint requires multi-model as a viable shipped configuration, not just a future spike outcome.
- **Direct OpenCode HTTP API instead of `opencode run` CLI** — out of scope; existence/access not investigated.

## References

- Frame artifact: `.scratch/opencode-models-tier-frame-97c5/frame-artifact.md`
- Design artifact: `.scratch/opencode-models-tier-frame-97c5/design-artifact.md`
- Per-model benchmark research: `.scratch/opencode-models-tier-frame-97c5/research-models.md`
- Advisory synthesis: `.scratch/opencode-models-tier-frame-97c5/advise-synthesis.md`
- Current tier system orient: `.scratch/opencode-models-tier-frame-97c5/orient.md`
- `skills/use-envoy/scripts/_common.sh` — `resolve_tier()` (lines 71-86)
- `skills/use-envoy/scripts/invoke-opencode.sh` — single-model dispatch (lines 64-65)
- `skills/use-envoy/scripts/run.sh` — multi-mode parallel-fan-out precedent (lines 158-167)
- `install.sh` — `map_model_for_provider()` (lines 1119-1144)
- `docs/multi-model-council-sizing.md` — council-of-three principles
- Concurrency reference impl: `oc_py_wrapper` (community), navigator advisory
- OpenCode SQLite issues: GitHub #21215, #15188, #17516, #4251

## Progress

See `progress.md` (created/updated by `/do-build` per slice completion).
