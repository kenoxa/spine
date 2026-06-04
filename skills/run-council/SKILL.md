---
name: run-council
description: >-
  Thinking-lens stress-test on a recommendation.
argument-hint: "[advise_synthesis_path, source_artifact_path]"
---

Sequences after run-advise. Receives `advise-synthesis.md` + `{source_artifact_path}` by path. Dispatches 5 thinking-lens advisors (Standard tier via `@advisor`). Chairman (`@synthesizer` + `council-synthesis.md` ref) resolves all conflicts and emits `council-synthesis.md`.

**Session**: Inherit calling skill's session ID. When standalone, generate per SPINE.md.

**Phase Trace**: per phase-audit.md table format. Log at intake, batch, peer-review, chairman, output. Include dispatch count.

## Phases

**Subagent references** (backticked): dispatch to subagent — do NOT Read into mainthread.

| # | Phase | Type | Agent | Reference |
|---|-------|------|-------|-----------|
| 1 | Intake | mainthread | — | — |
| 2 | Batch | C (5 agents) | `@advisor` (×5, one per lens) | `references/council-dispatch.md` |
| 3 | Peer Review | mainthread + C (5 agents) | `@advisor` (×5) | `references/council-peer-review.md` |
| 4 | Chairman | C (1 agent) | `@synthesizer` | `references/council-synthesis.md` |
| 5 | Output | mainthread | — | — |

### 1. Intake

Accept from caller:
- `{advise_synthesis_path}` (default: `.scratch/<session>/advise-synthesis.md`) — path to run-advise output
- `{source_artifact_path}` — path to the original decision object (frame artifact, discuss artifact, or intake)

**Skip condition** (evaluate before dispatching):

Read `{advise_synthesis_path}`. Check BOTH conditions:
1. Zero `[DIVERGENCE]` or `[CONFLICT]` tags anywhere in `{advise_synthesis_path}`
2. `blast_radius.transitive` field in `{source_artifact_path}` is empty or absent

Note: condition 2 is satisfied by absence — if the field does not exist, treat it as empty.

If BOTH conditions hold: write `.scratch/<session>/council-synthesis.md` with all required output fields:
```
Input status: N/A — ratified (skip condition met; no advisor dispatches)
Convergence Zones: N/A — ratified
Genuine Disagreements: N/A — ratified
Collective Blind Spots: N/A — ratified
Single Directional Recommendation: advise-synthesis recommendation ratified — no divergence or transitive blast radius detected. Council dispatch skipped.
Confidence: E2 (skip condition verified by reading advise-synthesis; no divergence detected)
Falsification: N/A — ratified
Delta from advise-synthesis: N/A — ratified
```
Then STOP. Do not proceed to Batch.

If either condition fails: proceed with full dispatch.

Exit: dispatch context assembled with `{advise_synthesis_path}` and `{source_artifact_path}` confirmed to exist. Pass both as paths — do not inline-extract content.

### 2. Batch

Dispatch in parallel — one `@advisor` per lens. Each advisor receives:
- Its lens file from the table below — its own definition only, not the full set
- `{advise_synthesis_path}` by path
- `{source_artifact_path}` by path
- `output_path`: `.scratch/<session>/council-advisor-{lens-slug}.md`

Lenses, files, and slugs:

| Lens | Slug | Lens file | Output file |
|------|------|-----------|-------------|
| Contrarian | `contrarian` | `references/council-lens-contrarian.md` | `council-advisor-contrarian.md` |
| First Principles | `first-principles` | `references/council-lens-first-principles.md` | `council-advisor-first-principles.md` |
| Expansionist | `expansionist` | `references/council-lens-expansionist.md` | `council-advisor-expansionist.md` |
| Outsider | `outsider` | `references/council-lens-outsider.md` | `council-advisor-outsider.md` |
| Executor | `executor` | `references/council-lens-executor.md` | `council-advisor-executor.md` |

**Cap**: 5 dispatches. Wait for all 5 to complete before proceeding.

### 3. Peer Review

1. **Anonymize**: run `sh "${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/run-council/scripts/anonymize-advisors.sh" .scratch/<session>/` — outputs `council-advisor-anon-{A–E}.md` + `council-anon-map.json` in the session directory. Fail if any of the 5 batch outputs from Phase 2 are missing.
2. **Dispatch in parallel** — one `@advisor` per lens via `references/council-peer-review.md`. Each receives:
   - Its lens file (same as Batch — own definition only)
   - `{anon_dir}`: `.scratch/<session>/` (session directory containing the anonymized outputs)
   - `output_path`: `.scratch/<session>/council-peer-{lens-slug}.md`
3. **Wait** for all 5 peer reviews to complete before proceeding.

**Cap**: 5 dispatches.

### 4. Chairman

Sequential `@synthesizer` dispatch via `references/council-synthesis.md`. Receives:
- Paths to all 5 advisor batch outputs in `.scratch/<session>/`
- Paths to all 5 peer review outputs in `.scratch/<session>/`
- `{anon_map_path}`: `.scratch/<session>/council-anon-map.json`
- `{advise_synthesis_path}`
- `{source_artifact_path}`
- `output_path`: `.scratch/<session>/council-synthesis.md`

Retry once on empty output; halt and surface error on second failure.

### 5. Output

Return `council_artifact` (path to `.scratch/<session>/council-synthesis.md`) to caller (workflow orchestrator or user).

- **Embedded**: return `council_artifact` to caller.
- **Standalone**: present synthesis to user for decision.

## Anti-Patterns

- Dispatching without run-advise having run first — `{advise_synthesis_path}` is a mandatory precondition
- Passing advise-synthesis content inline instead of by path — inline extraction breaks the shared-decision-object convention
- Using `@consultant` for advisor dispatches — `@consultant` is hard-pinned Frontier/opus; use `@advisor` (Standard/sonnet)
- Skipping skip-condition check at Intake — Council is always-on; the check prevents full dispatch when ratification applies
- "Chairman should surface conflicts without resolving" — Chairman MUST resolve; the synthesizer's default "do not resolve" is overridden by `council-synthesis.md`
- Running Peer Review before all 5 Batch outputs exist — anonymize-advisors.sh enforces this; do not skip
- Passing anonymized output content inline to peer reviewers — pass the session directory path (`{anon_dir}`), not file contents

## Completion

- Phase Trace rows for intake, batch, peer-review, chairman, output [E3]
- Skip condition evaluated at intake [E2]
- All 5 batch outputs exist or gap-flagged [E3]
- `council-anon-map.json` written with all 5 slug→letter mappings [E3]
- All 5 peer review outputs exist or gap-flagged [E3]
- `council-synthesis.md` Input status field present (advisor files confirmed or gaps reported) [E3]
- `council-synthesis.md` written with: Convergence Zones, Genuine Disagreements, Collective Blind Spots, Single Directional Recommendation, Confidence, Falsification, Delta from advise-synthesis [E3]
