---
name: run-skill-eval
description: >
  Generate variations, eval all variants (HEAD/working/optimized) via claude CLI,
  report via @visualizer. Iterate until optimal.
  Use when: /run-skill-eval, "optimize my skills", "evaluate changed skills",
  "find the best version", skill quality before committing.
  Do NOT use for creating new skills (skill-creator), code review (run-review),
  or one-off skill authoring review (use-skill-craft).
argument-hint: "[file paths...] [--model model-id] [--base git-ref]"
---

**Optimize** (generate variations) → **Evaluate** (`claude -p`) → **Report** (@visualizer HTML) → iterate.

## Step 0: Detection + Setup

### File discovery

Priority order:
1. **Explicit paths** — user-provided file arguments; use as-is
2. **Auto-discover** — changed evaluatable files:
   ```
   git diff --name-only ${base:-HEAD}   # tracked changes
   git status --porcelain               # untracked (??) files
   ```
   Filter to: `*/SKILL.md`, `agents/*.md`, `AGENTS.md`, `CLAUDE.md`, `**/CLAUDE.md`
   Deduplicate. No files → "No evaluatable changes detected." → exit.

### Grouping by eval unit

| Pattern | Unit type |
|---------|-----------|
| `<dir>/SKILL.md` + sibling `references/*.md` | skill unit |
| `agents/<name>.md` | agent unit |
| `CLAUDE.md` / `AGENTS.md` / `@`-included files | instruction unit |

### Always-loaded file detection

Parse root `CLAUDE.md` `@` includes. Changed included file → always-loaded flag (cross-cutting eval, Step 2).

### Baseline snapshots

```
git show ${base:-HEAD}:<path> > .scratch/<session>/baselines/<path>
```

### Cross-reference expansion

Grep changed ref filenames across all `SKILL.md`; add transitive consumers to eval set.

### Eval mode classification

Classify each unit: `tool-dependent` (body references Agent, @-agent, Read, Write, Grep, Glob, Bash, or dispatch) vs `text-only` (no tool/agent references). Grep skill body excluding anti-patterns section. Classification determines whether calibration runs in Step 2.

---

## Step 1: Optimize — Generate Variations

### Craft review

Dispatch `@spine:run-skill-eval:reviewer` per eval unit. Output: `.scratch/<session>/optimize/<unit>/craft-findings.md`.

### Variation generation

Dispatch `@spine:run-skill-eval:optimizer` 1-2 times per unit (one per strategy: `compress`, `restructure`, or custom based on craft findings). Each receives working copy, baseline, and craft findings.

- Output: `.scratch/<session>/optimize/<unit>/variation-<strategy>.md`
- Cap: 1-3 variations per unit (diminishing returns beyond 3)

### Result per eval unit

Candidates: baseline (HEAD), working (current), + variations.

---

## Step 2: Evaluate — Compare Variants via Claude CLI

### Test prompt generation

Auto-generate 2-3 test prompts per eval unit from:
- Skill's description / trigger phrases
- Changed sections (what was modified)
- Cross-references (how consumers use this unit)

### Test fixture setup

Skills that dispatch subagents need **real file context** — a model won't dispatch @inspector agents against a diff embedded in text. For skills with dispatch, codebase interaction, or file I/O:

1. Create a test fixture directory: `.scratch/<session>/eval-fixtures/<prompt-name>/`
2. Write actual source files matching the test scenario (both "before" and "after" states)
3. Initialize as a git repo with the "before" state committed and "after" state as uncommitted changes
4. The eval prompt references files by path (not inline diff) — e.g., "Review the uncommitted changes in this repository"

```sh
FIXTURE_DIR=".scratch/<session>/eval-fixtures/<prompt-name>"
mkdir -p "$FIXTURE_DIR"
# Write test source files, init git repo, create test diff
cd "$FIXTURE_DIR" && git init && git add -A && git commit -m "baseline"
# Apply test changes (uncommitted) so the model sees a real diff
```

For skills that are purely text-processing (no file dispatch): inline prompt with prepended variant content is sufficient — skip fixture setup.

### Eval dispatch

Dispatch `@spine:run-skill-eval:runner` per eval unit. Each subagent receives:
- Variant files + eval prompts for this unit
- Fixture directory path
- Eval mode classification (tool-dependent / text-only)
- Output path: `.scratch/<session>/eval/<unit>/`

`@spine:run-skill-eval:runner` handles calibration (tool-dependent units), eval execution, and metrics extraction. Main thread reads `calibration-result.json` (pass/fail gate) and `metrics.json` per run — never raw stream-json.

- Always-loaded files: include via `--append-system-prompt` (cross-cutting isolation)

### Grading

Dispatch `@spine:run-skill-eval:grader` per eval unit:
- Receives expectations + eval output dir from `@spine:run-skill-eval:runner`
- Checks calibration gate before grading (tool-dependent units)
- Grades each variant against expectations using both text output and `metrics.json`
- Writes `grading.json` per variant + `grading-summary.md` per unit
- Orchestrator reads **summaries only** — never full grading.json (context management)

### Aggregation + comparison

Run skill-creator's `scripts/aggregate_benchmark.py` per unit.

Produces `benchmark.json` comparing all variants: pass rates, timing, token usage.
**Winning variant** per unit: highest pass rate → lowest tokens as tiebreak.

### Cross-cutting eval (conditional)

When always-loaded files changed, isolate instruction impact:
- Baseline: HEAD instruction + HEAD skill
- Test: working instruction + HEAD skill (isolates instruction change)
- If skills also changed: additional config with both working

---

## Step 3: Report + Iterate

Dispatch `@visualizer`: comparison dashboard — variant × unit pass rates, token delta vs baseline, winning variant highlighted, per-unit assertion breakdown, craft-review findings. Data: [grading-summary.md, benchmark.json paths]. Output: `.scratch/<session>/optimize-report.html` (iteration N: `iteration-<N>/optimize-report.html`).

### Report content

- Per-unit comparison table: variant | pass rate | assertions passed/total | tokens | timing | delta vs baseline
- Winning variant highlighted per unit
- Craft-review findings
- Cross-cutting results (if applicable)
- Per-assertion detail: which assertions each variant passed/failed
- Recommendation: adopt winning variant or iterate further

### Output

`.scratch/<session>/optimize-report.html` — opened in browser.

### Clean-pass format

Even when all variants score identically: list every file checked, assertion count, variants compared, baseline commit. Never omit the comparison table.

### Iteration

After user reviews the report:

1. **Satisfactory** → user applies winning variant; done
2. **Further optimization needed:**
   - Read user feedback on what to improve
   - Generate new variations targeting specific weaknesses
   - Re-run Step 2 with new variants + previous best
   - Re-run Step 3 with `--previous` iteration for comparison
   - Iteration workspace: `.scratch/<session>/iteration-<N>/`

---

## Anti-Patterns

- Reimplementing skill-creator's grading/benchmark internals — use its scripts
- Using `git diff` alone without `git status --porcelain` for untracked files
- Reading full `grading.json` in orchestrator — summaries only (context management)
- Evaluating always-loaded file changes in same config as skill changes — isolate
- Generating trivially simple eval prompts that won't trigger skill invocation
- Embedding diffs as inline text instead of creating fixture repos — model won't dispatch subagents against text-only context
- Prepending skill content to user message instead of system prompt — model treats it as informational context, not directives
- Skipping optimization step — going straight to eval without generating variations
- Stopping after one iteration when user feedback suggests further improvement
- Writing markdown report instead of dispatching `@visualizer`
- Using `declare -A` or other bash 4+ features — macOS ships bash 3.2; use `#!/bin/sh` and per-variant files
- Generating visual report on main thread — always dispatch `@visualizer` subagent
- Reading grading summaries on main thread before `@visualizer` dispatch — subagent reads them directly
- Passing `<session>` placeholder in `@visualizer` dispatch — inject the literal resolved session path and enumerated unit paths
- Dispatching `@visualizer` without scoping output_path to `iteration-<N>/` for iterated runs
- Reading raw stream-json on main thread — dispatch `@spine:run-skill-eval:runner`, read `metrics.json` summaries only
