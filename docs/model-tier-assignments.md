---
updated: 2026-04-02
---

# Agent Tier Assignments

Durable reference for AI sessions. Full detail in `docs/model-selection.md`.

## Current Assignments

| Agent | Tier | Rationale |
|-------|------|-----------|
| consultant, debater, inspector, synthesizer, verifier | Frontier | Gate authority — quality of judgment and merge quality must exceed routine implementation |
| analyst, curator, envoy, implementer, navigator, researcher, visualizer | Standard | Advisory, research, cross-provider dispatch, and implementation with a Standard floor |
| miner, scout | Fast | Retrieval — speed over depth |

Source: `docs/model-selection.md` agent table + agent frontmatter.

**Synthesizer (Frontier) vs implementer (Standard).** Not a tier mismatch: the synthesizer merges multiple subagent outputs behind the thin-orchestrator firewall (merge authority, quality-sensitive consolidation). The implementer executes scoped partition edits from a plan — not a merge gate — and is pinned to Standard so a Fast mainthread cannot drag writes to Fast-tier quality. See `docs/architecture.md` (thin orchestrator + tier system).

## Session Model (Main-Thread)

**Standard is the recommended default** (sonnet:medium / gpt-5.4:medium / auto).

Sonnet 4.6 scores 79.6% SWE-Bench Verified vs Opus 4.6's 80.8% — 1.2-point gap at 40% lower input cost. On orchestration-adjacent tasks (tool use, structured task execution, agent coordination), Sonnet 4.6 matches or leads Opus 4.6. Frontier subagents (consultant, inspector, verifier, synthesizer) handle gate decisions regardless of session model.

Rolling window is cost-weighted: Opus drains the 5h/7-day window ~1.67× faster than Sonnet.

## Escalation: Session (Upgrade Mainthread to Frontier)

Use when the **orchestrator conversation** is the bottleneck:

- Session context exceeds ~50K tokens accumulated across subagent interactions
- Phase-gating requires 5+ simultaneous preconditions with complex interdependencies
- Conflicting/ambiguous subagent outputs requiring nuanced synthesis beyond structured routing

## Escalation: Implementer Workload (Not the Orchestrator)

Use when **implementation** is the bottleneck but you might keep a cheaper session for planning overhead:

- Multi-file architectural refactoring where the design artifact cannot fully specify cross-cutting concerns — escalate **implementation** (e.g. `@implementer` tier or partition scope), not "run everything on Opus" by default

If the mainthread cannot hold the task state or routing breaks down, upgrade the **session**; implementer-only escalation does not fix orchestration limits.

## Provider Notes

- **Cursor**: `auto` and `composer-2` draw from the same included pool — no cost advantage between them. Both are cheaper than API-pool models (Claude/GPT selections).
- **Codex**: Frontier/Standard both use `gpt-5.4`; differentiated by effort level (high vs medium). GPT-5.4-mini (Fast) rejected for main-thread — 33.6% MRCR v2 long-context score is unacceptable for orchestrators accumulating multi-phase output.
