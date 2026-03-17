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

## Agent Roster

| Agent | Role |
|-------|------|
| `@spine:run-skill-eval:reviewer` | Craft review per unit |
| `@spine:run-skill-eval:optimizer` | Generate optimized variants |
| `@spine:run-skill-eval:designer` | Design quality + trigger eval test cases |
| `@spine:run-skill-eval:runner` | Calibration + eval execution + metrics extraction |
| `@spine:run-skill-eval:grader` | Grade variant outputs against expectations |

Workspace: `.scratch/<session>/benchmark/<unit>/` per eval unit.

## Step 0: Detection + Setup

### File discovery

Priority order:
1. **Explicit paths** — user-provided file arguments; use as-is
2. **Auto-discover** — changed evaluatable files:
   ```sh
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

```sh
git show ${base:-HEAD}:<path> > .scratch/<session>/baselines/<path>
```

### Cross-reference expansion

Grep changed ref filenames across all `SKILL.md`; add transitive consumers to eval set.

### Skill-creator path resolution

```sh
SKILL_CREATOR_DIR="$(jq -r '.plugins["skill-creator@claude-plugins-official"][0].installPath' ~/.claude/plugins/installed_plugins.json)/skills/skill-creator"
```

Resolve once. Verify the path exists — if `null` or missing, skill-creator plugin is not installed. All subsequent steps reference `$SKILL_CREATOR_DIR`.

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

### Test fixture setup

Skills that dispatch subagents need **real file context** — a model won't dispatch @inspector agents against a diff embedded in text. For skills with dispatch, codebase interaction, or file I/O:

1. Create a test fixture directory: `.scratch/<session>/eval-fixtures/<unit>/`
2. Write actual source files matching the test scenario (both "before" and "after" states)
3. Initialize as a git repo with the "before" state committed and "after" state as uncommitted changes
4. The eval prompt references files by path (not inline diff) — e.g., "Review the uncommitted changes in this repository"

```sh
FIXTURE_DIR=".scratch/<session>/eval-fixtures/<unit>"
mkdir -p "$FIXTURE_DIR"
# Write test source files, init git repo, create test diff
cd "$FIXTURE_DIR" && git init && git add -A && git commit -m "baseline"
# Apply test changes (uncommitted) so the model sees a real diff
```

For skills that are purely text-processing (no file dispatch): inline prompt with prepended variant content is sufficient — skip fixture setup.

### Test case design (@designer)

Dispatch `@spine:run-skill-eval:designer` per eval unit. Dispatch receives:
- `unit_path` — eval unit file path
- `unit_type` — skill | agent | instruction
- `craft_findings_path` — `.scratch/<session>/optimize/<unit>/craft-findings.md`
- `baseline_path` — `.scratch/<session>/baselines/<path>`
- `working_copy_path` — current file path
- `benchmark_dir` — `.scratch/<session>/benchmark/<unit>/`

Output:
- `<benchmark_dir>/evals.json` — quality eval test cases (IDs must be sequential integers)
- `<benchmark_dir>/trigger-evals.json` — trigger eval set for description optimization

**Gate**: verify `evals.length > 0` after dispatch. Zero evals → fail with diagnostic.

### Eval dispatch (@runner)

Dispatch `@spine:run-skill-eval:runner` per eval unit. Each receives:
- `evals_json_path` — `<benchmark_dir>/evals.json`
- `benchmark_dir` — `.scratch/<session>/benchmark/<unit>/`
- `variant_files` — list of variant file paths (baseline, working, variation-*)
- `fixture_dir` — `.scratch/<session>/eval-fixtures/<unit>/`
- `eval_mode` — `tool-dependent` or `text-only`

Output layout:
```
<benchmark_dir>/
  eval-<id>/
    eval_metadata.json
    <variant>/
      run-1/
        eval_metadata.json
        outputs/
          output.jsonl
        metrics.json
        timing.json
```

Calibration output goes to `.scratch/<session>/calibration/<unit>/` — separate from benchmark dir. Main thread reads `calibration-result.json` (pass/fail gate) and `metrics.json` per run — never raw stream-json.

- Always-loaded files: include via `--append-system-prompt` (cross-cutting isolation)

### Grading (@grader)

Dispatch `@spine:run-skill-eval:grader` per eval unit:
- `benchmark_dir` — `.scratch/<session>/benchmark/<unit>/` (grader iterates the hierarchy itself)
- `calibration_result_path` — `.scratch/<session>/calibration/<unit>/calibration-result.json`
- `expectations` — assertions from evals.json

Grader checks calibration gate, grades each variant against expectations using both text output and `metrics.json`, writes `grading.json` per variant + `grading-summary.md` per unit.

Orchestrator reads **summaries only** — never full grading.json (context management).

### Aggregation

Run aggregation per unit (uses `$SKILL_CREATOR_DIR` from Step 0):
```sh
python3 "$SKILL_CREATOR_DIR/scripts/aggregate_benchmark.py" \
  .scratch/<session>/benchmark/<unit>/ \
  --skill-name <unit-name>
```

Produces `benchmark.json` comparing all variants: pass rates, timing, token usage.
**Winning variant** per unit: highest pass rate → lowest tokens as tiebreak.

### Cross-cutting eval (conditional)

When always-loaded files changed, isolate instruction impact:
- Baseline: HEAD instruction + HEAD skill
- Test: working instruction + HEAD skill (isolates instruction change)
- If skills also changed: additional config with both working

---

## Step 3: Report + Iterate

### Viewer choice

Present choice BEFORE generating reports: "Review per-run outputs (generate_review.py) or skip to comparison dashboard (@visualizer)?"

### Per-run review (generate_review.py, if chosen)

```sh
python3 "$SKILL_CREATOR_DIR/eval-viewer/generate_review.py" \
  .scratch/<session>/benchmark/<unit>/ \
  --skill-name <unit-name> \
  --benchmark .scratch/<session>/benchmark/<unit>/benchmark.json \
  --static .scratch/<session>/benchmark/<unit>/review.html
```

For iterations: add `--previous-workspace .scratch/<session>/benchmark/<unit>/` (or `iteration-<N-1>/` for N>2).

### Comparison dashboard (@visualizer)

Dispatch `@visualizer`: comparison dashboard — variant x unit pass rates, token delta vs baseline, winning variant highlighted, per-unit assertion breakdown, craft-review findings. Data: [grading-summary.md, benchmark.json paths]. Output: `.scratch/<session>/optimize-report.html` (iteration N: `iteration-<N>/optimize-report.html`).

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

### Description optimization (opt-in)

Triggered by: explicit user request, iteration plateau, or post-final acceptance.

**Preflight checks** (all blocking):
1. Locate skill-creator via `installed_plugins.json` (same resolution as aggregation)
2. `trigger-evals.json` exists at `<benchmark_dir>/trigger-evals.json` with >= 2 entries
3. Unit has valid SKILL.md with `---` frontmatter
4. `python3 -c "import anthropic"` succeeds
5. `ANTHROPIC_API_KEY` env var set

```sh
cd "$SKILL_CREATOR_DIR" && python3 -m scripts.run_loop \
  --eval-set <trigger-evals-path> \
  --skill-path <unit-dir> \
  --model ${model:-sonnet} \
  --max-iterations 5 \
  --verbose \
  --results-dir .scratch/<session>/description-opt/
```

`run_loop.py` creates a timestamped subdirectory under `--results-dir`. Discover it, then read `results.json` within → present `best_description` to user → apply if approved.

### Iteration

After user reviews the report:

1. **Satisfactory** → user applies winning variant; done
2. **Further optimization needed:**
   - Read user feedback on what to improve
   - Generate new variations targeting specific weaknesses
   - Re-run Step 2 with new variants + previous best
   - Re-run Step 3 with `--previous` iteration for comparison
   - Re-run workspace: `.scratch/<session>/benchmark/<unit>/iteration-<N>/`
   - First run lives at `.scratch/<session>/benchmark/<unit>/` directly — `iteration-1/` never exists

For iterations using `generate_review.py`: add `--previous-workspace` pointing to the prior iteration directory.

---

## External Contract Versions

- `skill-creator@claude-plugins-official` — contracts validated against `d5c15b861cd2` (resolved at runtime via `installed_plugins.json`)

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
- Passing quality evals (evals.json) to `run_loop.py` — it expects `[{query, should_trigger}]` format (trigger-evals.json)
- Using non-numeric eval IDs — `aggregate_benchmark.py` expects integer directory names
- Calling `run_loop.py` without `ANTHROPIC_API_KEY` env var set
- Calling `run_loop.py` without `cd` to skill-creator dir first
- Using `find` to locate skill-creator instead of `installed_plugins.json`
- Calling `run_loop.py` without verifying SKILL.md `---` frontmatter exists
- Placing calibration output inside benchmark dir — `aggregate_benchmark.py` would include them
- Omitting `outputs/` directory in run layout — `generate_review.py` requires `outputs/output.jsonl`
- Reading `benchmark.md` as authoritative for N>2 configs — use `benchmark.json`
- Conflating description optimization and quality optimization in same iteration
- Reusing benchmark dirs from sessions before this layout change
