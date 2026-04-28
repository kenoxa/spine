---
created: 2026-04-28
confidence: high
session: model-incorporation
---

# Model Incorporation Spec

## Problem

Spine sessions and subagents need per-provider, per-tier model mappings grounded in current (Spring 2026) market data rather than stale defaults or ad-hoc selection. The three-tier backbone (Frontier/Standard/Fast) is architecturally settled, but the concrete model names assigned to each tier were untested against available benchmarks, pricing, and real-world agentic behavior.

## Constraints

| Type | Description | Source |
|------|-------------|--------|
| hard | Three-tier agent system (Frontier/Standard/Fast) must remain intact | codebase |
| hard | Agent frontmatter schema cannot change without install.sh updates | codebase |
| hard | No runtime changes — provider routing already exists in `skills/use-envoy/scripts/_common.sh` | codebase |
| soft | Model names must be per-provider, not one-size-fits-all | architecture |
| soft | Justifications must be architecture-anchored, not benchmark-anchored (see Narrative Durability) | design |

## Key Decisions

1. **Documentation-only approach.** The three-tier system and envoy routing already support arbitrary model names. No runtime code changes needed. The only output is a provider mapping table in `docs/model-tier-assignments.md` and supporting prose in `docs/model-selection.md`. This is the highest-confidence path — zero blast radius on behavior.

2. **OpenCode Go main-thread: not the strongest model, the best quality/volume balance.** Long-lived orchestrator sessions accumulate context and fire many tool calls. The orchestrator needs drift resistance and sustainable request economics, not peak benchmark scores. This rules out DeepSeek V4 Pro (verbose/drifty over long loops) and DeepSeek V4 Flash (too weak as decision authority). GLM-5.1 is too request-expensive for a default. Kimi K2.6 during promotional pricing, MiniMax M2.7 as the durable fallback.

3. **Claude Code: Sonnet owns the thread. Opus interrupts for judgment.** Sonnet 4.6 is the default main-thread model — strong enough for orchestration, sustainable over many turns. Opus is escalation only (heavy architecture checkpoints, final critical review, stuck debugging). Haiku is cheap fan-out (explore, quick reviews, summarization). This maps to the three tiers cleanly: Standard/Sonnet, Frontier/Opus, Fast/Haiku.

4. **DeepSeek V4 Pro: hard worker, not orchestrator.** Pro is objectively strong on coding benchmarks (SWE-Bench Verified 80.6, Terminal Bench 67.9) but verbose (~37.7 t/s) and prone to drift in long agent loops. It belongs in the Standard tier as an implementer/envoy — scoped, deep work — not as a long-lived main thread.

5. **DeepSeek V4 Flash: fan-out only.** Flash is the highest-volume model in OpenCode Go (~158K requests/month) with surprisingly strong coding scores (SWE-Bench Verified 79.0, LiveCodeBench 91.6). But it is not a decision authority. Assign to Fast tier for explore, quick reviews, hypothesis generation, grep-like codebase search.

6. **Provider table added to `model-tier-assignments.md`.** The table maps Frontier/Standard/Fast to concrete model names per provider (Claude Code, OpenCode Go, OpenCode Free, Codex, Cursor). This is the canonical lookup that AI sessions use when selecting models.

## Blast Radius

| Scope | Artifacts | Risk |
|-------|-----------|------|
| Direct | `docs/model-tier-assignments.md` (provider mapping table + provider notes), `docs/model-selection.md` (session model guidance) | Low — docs only, no code paths |
| External | AI sessions reading docs for model selection guidance | Low — stale names get updated to researched names |
| Reference | `docs/model-research.md` — detailed market analysis, not touched by this spec | None |

## Success Criteria

1. An AI session in OpenCode Go reads `docs/model-tier-assignments.md` and routes Frontier to `kimi-k2.6`, Standard to `minimax-m2.7`, Fast to `deepseek-v4-flash` — matching the researched quality/volume balance for each role.
2. An AI session in Claude Code sees Sonnet as the session default with Opus as escalation only, Haiku for cheap fan-out — matching the "Sonnet owns the thread" principle.
3. The mapping is justifiable without citing specific benchmark deltas — architecture-anchored (role requirements, not score gaps).
4. `docs/model-research.md` is referenced as the authoritative source for benchmark data and market analysis, avoiding duplication.

## Key Unknowns

None remaining. All discuss-phase unknowns were resolved by the research phase: (a) whether existing runtime mappings match market reality → yes, validated; (b) whether code changes are needed → no, documentation-only; (c) whether the three-tier system needs restructuring → no, confirmed adequate; (d) whether provider-specific model names diverge significantly → yes, requiring the provider mapping table.

---

**Decision**: Proceeded to documentation implementation. `docs/model-tier-assignments.md` updated with provider mapping table and provider notes. `docs/model-selection.md` updated with session model guidance.

**Confidence**: HIGH — all mapping decisions are grounded in multi-source research (full market analysis + provider-specific recommendations) and validated against existing architecture constraints.

**Research source**: `docs/model-research.md` (synthesized from all three research documents).
