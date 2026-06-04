---
name: run-advise
description: >-
  Use when: 'get perspectives', 'second opinion', 'sanity check', 'what am I missing'.
argument-hint: "[problem, approach question, or frame_artifact]"
---

Standalone (user question) or embedded (`frame_artifact` from caller). Dispatches multi-model perspectives, synthesizes into directional recommendation.

**Session**: Generate per SPINE.md. When embedded, inherit calling skill's session ID.

**Phase Trace**: per phase-audit.md table format. Log at intake, batch, synthesis, output. Include dispatch count.

## Phases

**Subagent references** (backticked): dispatch to subagent -- do NOT Read into mainthread.

| # | Phase | Type | Agent | Reference |
|---|-------|------|-------|-----------|
| 1 | Intake | mainthread | — | — |
| 2 | Batch | C (4 agents) | `@consultant` (x2) + `@navigator` + `@envoy` | `references/advise-dispatch.md`, `references/advise-navigator.md`, `references/advise-envoy.md` |
| 3 | Synthesis | C (1 agent) | `@synthesizer` | `references/advise-synthesis.md` |
| 4 | Output | mainthread | — | — |

### 1. Intake

Accept: question from user (standalone) OR frame_artifact/context from caller (embedded).

- **Standalone with thin input** (fewer than 3 concrete constraints/criteria): before asking the user a grounding question, attempt to derive constraints via a quick `@scout` codebase pass or Read of any referenced artifact. Ask the user only if the gap requires their judgment or domain knowledge.
- **Embedded with frame_artifact**: skip questions, dispatch directly.
- **Variance**: match task keywords against [variance-lenses.md](references/variance-lenses.md); select 0-2 lenses. A matched lens counts as one constraint toward the 3-constraint threshold. Freeze lenses on first dispatch — do not re-derive on re-dispatch rounds.

Exit: dispatch context assembled with >=3 constraints, OR frame_artifact present. Include selected lenses (if any) in dispatch context for all batch agents.

**`{source_artifact_path}`**: MUST pass to every batch agent + synthesis — repo-relative decision object (e.g. `.scratch/<session>/frame-artifact.md`, `discuss-artifact.md`, or thin standalone intake). Same path in `advise-synthesis` + `advise-envoy`.

### 2. Batch

Dispatch in parallel:
- `rigorous` (`@consultant`) → `references/advise-dispatch.md` (rigorous angle)
- `creative` (`@consultant`) → `references/advise-dispatch.md` (creative angle)
- `navigator` (`@navigator`) → `references/advise-navigator.md`
- `envoy` (`@envoy`) → `references/advise-envoy.md` (via `use-envoy`)

**Cap**: 4 dispatches. Output: `.scratch/<session>/advise-batch-{rigorous,creative,navigator,envoy}.md`.

### 3. Synthesis

Entry: all 4 batch outputs exist (or gap-flagged). Sequential `@synthesizer` via `references/advise-synthesis.md` with the same `{source_artifact_path}` as Phase 2. Retry once on empty; halt on failure. Output: `.scratch/<session>/advise-synthesis.md`.

### 4. Output

Present synthesis to caller/user as `advise_artifact`.

- **Standalone**: present for user decision.
- **Embedded**: return to caller.

### Re-dispatch

Triggered by user pushback after synthesis (via workflow orchestrator re-dispatch loop).

**Steps**:
1. **Archive**: invoke `sh "${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/run-advise/scripts/rotate-round.sh" <session-dir>` to archive current round outputs into `advise-r{N}/` subdirectory.
2. **Assemble context**: `prior_round_dir` = archived directory path (e.g., `advise-r1/`), `user_pushback` = inline text from user/caller.
3. **Return to Phase 2** (Batch) with re-dispatch context. Agents receive `prior_round_dir` + `user_pushback` and read selectively from the archived directory.

**Contract**: agents write to canonical paths (same as first round). Prior round is available at `{prior_round_dir}/`. Lenses frozen from first dispatch — do not re-derive.

**Barrier**: all 4 batch agents complete before synthesis (same as first round).

**Cap**: 3 re-dispatch rounds. Surface stall after cap.

## Anti-Patterns

- Producing implementation plans (directional advice only)
- Auto-resolving model disagreements (divergence is signal)
- Skipping batch dispatch and answering in mainthread
- "I can give good advice without external perspectives" — single-model advice has blind spots; batch is mandatory

## Completion

- Phase Trace rows for intake, batch, synthesis, output [E3]
- All 4 batch outputs exist or gap-flagged [E2]
- Synthesis written with convergence/divergence map [E2]
