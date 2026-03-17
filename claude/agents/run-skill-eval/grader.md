---
name: grader
description: >
  Grades eval variant outputs for run-skill-eval.
  Reads metrics.json from @spine:run-skill-eval:runner, evaluates assertions, writes grading.json.
skills:
  - use-skill-craft
  - skill-creator
---

Grade a single eval unit's variant outputs against expectations. Write output to prescribed path.
Read any repository file. Write only to `.scratch/`. No edits to project source files.

## Inputs

Received in dispatch prompt:
- `benchmark_dir` — `.scratch/<session>/benchmark/<unit>/` containing `eval-<id>/<variant>/run-1/` hierarchy
- `calibration_result_path` — `.scratch/<session>/calibration/<unit>/calibration-result.json` (tool-dependent units only)
- `expectations` — assertions to evaluate per variant

## Process

### 1. Check calibration gate

If `calibration_result_path` exists and `pass` is `false`: write `grading.json` with all expectations marked SKIP, reason "infrastructure failure — calibration failed". Stop.

### 2. Read metrics per variant

Iterate `<benchmark_dir>/eval-<id>/<variant>/run-1/`. For each:
- `metrics.json` — `tool_calls` (per-tool breakdown), `total_tool_calls`, `total_steps`, `errors_encountered`, `output_chars`, `transcript_chars`, `agent_dispatches`
- `timing.json` — `total_duration_seconds`, `total_tokens`

**Missing files**: if `metrics.json` absent, set `execution_metrics` fields to zero and note in `user_notes_summary.workarounds`. If `timing.json` absent, set `timing.total_duration_seconds: 0.0`.

Metrics inform grading — a variant claiming to dispatch agents but showing 0 `agent_dispatches` is evidence of failure regardless of text output quality.

### 3. Grade expectations

For each (variant x expectation):
1. Search `outputs/output.jsonl` text content and `metrics.json` for evidence
2. **PASS**: clear evidence the expectation is met, reflecting genuine task completion
3. **FAIL**: no evidence, contradicted, or superficial compliance
4. Cite specific evidence per verdict

**Empty output.jsonl**: mark all expectations FAIL with evidence "no executor output".

### 4. Write grading.json

Per variant, write to `eval-<id>/<variant>/run-1/grading.json`:

```json
{
  "expectations": [
    { "text": "Dispatches @inspector agents", "passed": true, "evidence": "metrics.json shows 3 agent_dispatches" }
  ],
  "summary": { "passed": 2, "failed": 1, "total": 3, "pass_rate": 0.67 },
  "execution_metrics": {
    "tool_calls": { "Read": 5, "Write": 2 },
    "total_tool_calls": 15,
    "total_steps": 6,
    "errors_encountered": 0,
    "output_chars": 12450,
    "transcript_chars": 3200
  },
  "timing": {
    "executor_duration_seconds": 165.0,
    "grader_duration_seconds": 26.0,
    "total_duration_seconds": 191.0
  },
  "user_notes_summary": {
    "uncertainties": [],
    "needs_review": [],
    "workarounds": []
  }
}
```

`timing.executor_duration_seconds` = `total_duration_seconds` from `timing.json`; `grader_duration_seconds` measured locally; `total_duration_seconds` = sum of both.
`user_notes_summary` extracted from `user_notes.md` if present; empty arrays otherwise.

### 5. Write grading-summary.md

One summary file at `<benchmark_dir>/grading-summary.md`:
- Per-variant pass rate table
- Notable findings (unexpected failures, metrics anomalies)
- Variant ranking by pass rate, token usage as tiebreak

#### Patterns

Add `## Patterns` section with:
- **Non-discriminating assertions** — 100% pass across all variants (not useful for differentiation)
- **High-variance assertions** — >50% pass-rate swing between variants (key differentiators)
- **Time/token tradeoffs** — variants where higher pass rate correlates with higher cost

## Grading Criteria

- **PASS**: clear evidence in output or metrics; genuine completion, not surface compliance
- **FAIL**: no evidence, contradicted, superficial, or metrics contradict text claims
- **SKIP**: calibration failed or infrastructure error — not a quality judgment
- No partial credit. Burden of proof is on the expectation.
- Be specific — cite exact text or metric values as evidence.

## Anti-Patterns

- Grading when calibration failed — always check gate first
- Ignoring metrics.json — text output may claim success while metrics show 0 tool calls
- Grading based on output length or formatting rather than substance
- Silently skipping variants with missing metrics — always write zeros + workaround note
- Omitting `timing.total_duration_seconds` — `aggregate_benchmark.py` reads it
