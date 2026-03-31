# Thin Orchestrator Architecture

Skills become minimal orchestrators that sequence subagent dispatches via file references. All behavioral instructions move to per-role reference files loaded by subagents or lazy-loaded by the mainthread.

## Problem

Large skill files (do-discuss ~4500, do-execute ~2900, do-plan ~2200 tokens) cause instruction forgetting. Context bleed hierarchy: reading subagent results back into mainthread (worst) > skill file size > conversation growth. The mainthread forgets dispatch rules, skips phases, or misroutes agents as context fills.

## Architecture

### Dispatch Protocol

```
Orchestrator (SKILL.md)
  1. Detect mode / classify input
  2. Lazy-load orchestrator reference (Tier B only)
  3. For each phase:
     a. Dispatch prompt = session dir + reference path + output path + prior output paths
     b. Dispatch subagent(s) — parallel when independent, sequential when dependent
     c. Wait for batch completion (implicit barrier)
     d. Chain: pass output paths to next phase OR dispatch synthesizer
  4. Approval gates at defined checkpoints
  5. Final synthesis: mainthread reads synthesized output, validates, declares readiness
```

### Composition Model

Agent files (250–1000 tokens) = base behavior. Reference files = task-specific instructions. Augmentation — reference adds to agent, never replaces.

### Synthesizer as Aggregation Proxy

Orchestrator never reads full subagent outputs. Dispatches synthesizer with file paths. Synthesizer reads, merges, writes result. Orchestrator reads synthesized output for routing OR chains to next phase via file refs.

### Reference File Types

| Type | Loaded by | Purpose | Naming |
|------|-----------|---------|--------|
| Role reference | Subagent | Instructions for one role | `{phase}-{role}.md` or `{role}.md` |
| Orchestrator reference | Mainthread (lazy) | Dispatch sequence for one mode | `orchestrate-{mode}.md` |
| Template | Subagent (synthesizer) | Output structure | `template-{artifact}.md` |
| Shared reference | Either | Cross-cutting concern | Descriptive name |

### Complexity Tiers

**Tier A — Routing Table** (~500–750 token SKILL.md)
Single dispatch sequence regardless of input. SKILL.md is a flat phase table.
Candidates: do-plan, run-review, run-debug, run-recap, run-insights, run-polish.

**Tier B — Mode-Specific Orchestrator References** (~250 token SKILL.md + one orchestrator ref per mode)
Multiple dispatch sequences selected by input shape. SKILL.md classifies input, lazy-loads matching orchestrator reference.
Candidates: do-discuss, do-execute.

### Reference File Guidelines

- **Per-role granularity**: each subagent loads exactly one reference matching its role. Zero noise from other roles.
- **Size target**: 250–800 tokens. Flag >1000 tokens for decomposition review.
- **Self-sufficiency**: understandable without the SKILL.md that dispatches it.
- **Orchestrator refs (Tier B)**: 1000–1500 tokens acceptable — replaces the full monolithic SKILL.md.
- **Measurement**: token counts via o200k_base encoding (e.g., `tokenizer -f <file> -m gpt-4.1`). ±2% vs Claude tokenizer at instruction-file scale.
- **Naming convention** — type-first prefix, consistent across all reference types:
  - Role: `{phase}-{role}.md` or `{role}.md` (e.g., `discovery-file-scout.md`, `planning.md`)
  - Orchestrator: `orchestrate-{mode}.md` (e.g., `orchestrate-normal.md`)
  - Template: `template-{artifact}.md` (e.g., `template-plan.md`, `template-brief.md`)
  - Shared: descriptive name (e.g., `variance-lenses.md`)

### Reference File Resolution

Skills are installed to `~/.agents/skills/<skill>/`. Reference files live at:

```
~/.agents/skills/<skill>/references/<file>.md
```

The orchestrator constructs absolute paths for dispatch prompts. Subagents receive the full path and load via Read tool — they have no implicit knowledge of the skill's location.

**Dispatch prompt includes:**
- Reference file: `~/.agents/skills/<skill>/references/<role>.md`
- Session dir: `.scratch/<session>/`
- Output path: `.scratch/<session>/<skill>-<phase>-<role>.md`
- Prior outputs: list of `.scratch/<session>/` paths from preceding phases

**Lazy-load by mainthread** (Tier B): the orchestrator reads its own orchestrator reference using the same path pattern. Since the skill loader resolves relative paths from SKILL.md, the orchestrator can also use relative `references/orchestrate-{mode}.md` links.

### Session Directory Handoff

- Output naming: `.scratch/<session>/<skill>-<phase>-<role>.md`
- Orchestrator constructs paths and passes them in dispatch prompt
- Subagents write to assigned path; read from prior paths passed to them
- Sequential access only — no concurrent writes to same file
- No manifest needed — orchestrator tracks paths because it constructs them

## Examples

### do-plan (Tier A)

```
skills/do-plan/
  SKILL.md                          # ~500 token orchestrator
  references/
    discovery-file-scout.md         # NEW — file-scout role
    discovery-docs-explorer.md      # NEW — docs-explorer role
    planning.md                     # NEW — planner role
    challenge.md                    # NEW — debater role
    synthesis.md                    # NEW — synthesizer merge
    template-plan.md                # EXISTING (rename from plan-template.md)
    variance-lenses.md              # EXISTING
    vertical-slices.md              # EXISTING
    deep-modules.md                 # EXISTING
    spec-mode.md                    # EXISTING
```

Dispatch flow:
1. Entry → session ID, variance lenses, spec-mode check
2. Discovery → dispatch @researcher (file-scout ref) + @researcher (docs-explorer ref) + @navigator in parallel → @synthesizer
3. Framing → mainthread distills planning_brief from synthesis
4. Planning → dispatch @planner (planning ref, rigorous) + @planner (creative) + @envoy → @synthesizer
5. Challenge → dispatch @debater (challenge ref, 3 personas) + @envoy → @synthesizer
6. Synthesis → mainthread reads final synthesis, assembles plan (references/template-plan.md) → readiness declaration

### do-discuss (Tier B)

```
skills/do-discuss/
  SKILL.md                          # ~250 token intake + lazy-load
  references/
    orchestrate-normal.md           # NEW — tier 1-3 dispatch sequence
    orchestrate-spec-creation.md    # NEW — spec-creation dispatch
    orchestrate-deep-interview.md   # NEW — deep-interview dispatch
    orient-scout.md                 # NEW — scout orient role
    clarify-assist.md               # NEW — between-round assists
    explore-framer.md               # NEW — framer explore role
    frame-synthesis.md              # NEW — synthesizer brief role
    template-brief.md               # EXISTING (rename from brief-template.md)
    template-spec.md                # EXISTING (rename from spec-template.md)
    spec-creation.md                # EXISTING
    spec-mode.md                    # EXISTING
```

Dispatch flow (normal mode):
1. Intake → classify → lazy-load `orchestrate-normal.md`
2. Orient (conditional) → @scout (orient-scout ref) + @navigator in parallel
3. Clarify → mainthread dialogue; between-round @scout/@navigator assists
4. Investigate (conditional) → @researcher / @scout / @navigator per unknown
5. Explore (conditional) → @framer team (explore-framer ref) + @navigator + @envoy
6. Frame → @envoy → @synthesizer (frame-synthesis ref) → brief.md
7. Handoff → confidence-gated recommendation

### do-execute (Tier B)

```
skills/do-execute/
  SKILL.md                          # ~250 token entry gate + depth classification
  references/
    orchestrate-focused.md          # NEW — inline execution (no subagents)
    orchestrate-standard.md         # NEW — standard dispatch sequence
    orchestrate-deep.md             # NEW — expanded fanout dispatch
    implement.md                    # NEW — implementer role
    quality-verifier.md             # NEW — verifier: correctness + spec compliance + E3 probes
    quality-risk-reviewer.md        # NEW — analyst risk review in quality phase
    quality-synthesis.md            # NEW — synthesizer merge for quality phase
    quality-envoy.md                # NEW — envoy dispatch for quality phase
    quality-fix.md                  # NEW — implementer fix from quality findings
    finalize.md                     # NEW — completion gates
```

## Constraints

### Hard Limits

- **Swarm cap**: ≤6 agents per dispatch batch (headroom below Claude Code ~10 limit)
- **No concurrent writes**: per-agent naming convention enforces isolation
- **Prompt-only data channel**: parent-to-child passes paths, not content
- **Implicit batch barrier**: all agents in one turn complete before orchestrator continues
- **Agent files unchanged** (skill migration phases): refactoring touches SKILL.md and references/ only. Relaxed during agent mode extraction (§ Migration > Agent Mode Extraction).

### Known Risks

| Risk | Mitigation |
|------|------------|
| File persistence failure (CC #4462) | Synthesizer verifies all expected inputs exist |
| Lock corruption at 7+ agents (CC #4473) | Stay within 6-agent cap |
| Sequential tasks degraded by parallelism | Clarify, framing, finalize remain mainthread-only |

## Migration

### Order

1. **do-plan** — Tier A, most predictable decomposition. Validates the pattern.
2. **do-execute** — Tier B, tests mode-specific orchestrator refs.
3. **do-discuss** — Tier B, most complex (tiered escalation, conditional phases).
4. **run-\* skills** — run-review, run-debug, run-recap, run-insights, run-polish. Tier A, lighter.
5. **Agent mode extraction** — terminal phase. Requires all skill migrations complete first.

### Per-Skill Migration Steps

1. Decomposition inventory: map SKILL.md sections → reference files (token budgets → target files)
2. Extract reference files — write new, verify self-sufficiency
3. Thin SKILL.md to orchestrator — replace inline instructions with dispatch + reference paths
4. Validate: run refactored skill on test task, compare output artifacts to baseline
5. Confirm all phases execute and all expected output files produced

### Agent Mode Extraction

Terminal phase — runs after all skill migrations complete. Agents become pure base behavior; all role-specific instructions move to reference files.

**Principle**: agent + reference = augmented behavior. Agents define *what* the role does generically. References define *how* in a specific skill context. Modes in agents are pre-baked references that belong in the reference layer.

**Scope**: 7 agents, ~20 roles total.

| Agent | Current modes | Type | Action |
|-------|--------------|------|--------|
| implementer | implement, polish-apply, quality-fix | explicit `## Mode Routing` | Extract bullets → skill refs |
| framer | stakeholder-advocate, systems-thinker, skeptic | explicit `## Mode Routing` | Extract bullets → skill refs |
| analyst | conventions-advisor, complexity-advisor, efficiency-advisor | explicit `## Mode Routing` | Extract bullets → skill refs |
| navigator | raw-docs, alternatives, synthesis | explicit `## Mode Routing` | Extract bullets → skill refs |
| scout | orient, trace, audit | explicit `## Thoroughness` | Extract bullets → skill refs |
| debater | thesis-champion, counterpoint-dissenter, tradeoff-analyst | implicit via dispatch | Author new skill refs |
| planner | rigorous, creative | implicit via dispatch | Author new skill refs |

**Per-agent steps**:

1. Consumer audit: identify all skills dispatching this agent (repo-wide, not just migration tracker)
2. For each consumer skill: verify a reference file exists covering the dispatched role. Author if missing.
3. Remove `## Mode Routing` (or equivalent) section from agent file
4. Clean base text: remove mode-name references (e.g., scout "Default to orient", navigator "mode: synthesis (default)")
5. Validate: run each consumer skill on a test task, confirm role behavior preserved

**Enforcement gate**: after extraction, no agent file contains mode enumeration and no skill dispatches an agent without a reference path.

### Risk Assessment

- Inline cross-references between phases may break when extracted
- Mainthread state that subagents currently inherit implicitly must become explicit in dispatch prompt
- Conditional logic spanning multiple sections needs careful untangling
- Non-tracked skills (e.g., run-architecture-audit dispatches @scout with audit thoroughness) depend on agent modes — consumer audit must be repo-wide
- Scout and navigator base text contains mode-name defaults requiring semantic rewrite, not just deletion
