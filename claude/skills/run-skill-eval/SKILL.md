---
name: run-skill-eval
description: >
  Generate variations, eval all variants (HEAD/working/optimized) via claude CLI,
  report via visual-explainer. Iterate until optimal.
  Use when: /run-skill-eval, "optimize my skills", "evaluate changed skills",
  "find the best version", skill quality before committing.
  Do NOT use for creating new skills (skill-creator), code review (run-review),
  or one-off skill authoring review (use-skill-craft).
argument-hint: "[file paths...] [--model model-id] [--base git-ref]"
---

**Optimize** (generate variations) → **Evaluate** (`claude -p`) → **Report** (visual-explainer HTML) → iterate.

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

---

## Step 1: Optimize — Generate Variations

### Craft review

Dispatch subagent per eval unit applying `use-skill-craft` and `skill-creator` skills criterias:
- Authoring test per line
- Red-flag scan (explanation without directive, verbose openers, multi-line anti-patterns)
- Size check, frontmatter validation
- Output: `.scratch/<session>/optimize/<unit>/craft-findings.md`

### Variation generation

Per eval unit, dispatch 1-2 optimization subagents. Each subagent prompt MUST include these files:
1. Working copy: `<path>` (the file being optimized)
2. HEAD baseline: `.scratch/<session>/baselines/<path>` (omit for create-mode files)
3. Craft findings: `.scratch/<session>/optimize/<unit>/craft-findings.md`

Each produces a variant with a distinct optimization angle:

| Variant | Strategy |
|---------|----------|
| `variation-compress` | Minimize token footprint; preserve all behavioral directives |
| `variation-restructure` | Improve clarity; reorder for progressive disclosure |
| Additional | Orchestrator's discretion based on craft findings |

- Write variants to `.scratch/<session>/optimize/<unit>/variation-<name>.md`
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

### Eval execution

Per (variant x prompt) combination:
```sh
unset CLAUDECODE                    # macOS nested session fix — ALWAYS include
claude -p --model ${model:-sonnet} < prompt-with-variant.md > output.md
```

- Prepend variant content to test prompt
- Always-loaded files: also prepend (cross-cutting isolation)
- Capture timing data per run

### Grading

Dispatch grader subagent per eval unit:
- Reads skill-creator's `agents/grader.md` for grading protocol
- Grades each variant's outputs against assertions
- Writes `grading.json` per variant: `text/passed/evidence` fields
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

Invoke `visual-explainer` skill → interactive HTML.

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
- Omitting `unset CLAUDECODE` in `claude -p` dispatch
- Skipping optimization step — going straight to eval without generating variations
- Stopping after one iteration when user feedback suggests further improvement
- Writing markdown report instead of using visual-explainer
