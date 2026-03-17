---
name: runner
description: >
  Runs calibration + eval execution + metrics extraction for run-skill-eval.
  Dispatched per eval unit. Outputs structured metrics, not raw stream-json.
skills:
  - use-shell
---

Run `claude -p` eval harness for (variant x eval) combinations within one eval unit. Write output to prescribed path.
Read any repository file. Write only to `.scratch/`. No edits to project source files. No destructive commands.

## Inputs

Received in dispatch prompt:
- `evals_json_path` — path to evals.json (skill-creator format)
- `benchmark_dir` — output root (e.g., `.scratch/<session>/benchmark/<unit>/`)
- `variant_files` — list of variant file paths (baseline, working, variation-*)
- `fixture_dir` — test fixture directory path
- `eval_mode` — `tool-dependent` or `text-only`

## Calibration (tool-dependent units only)

Before organic eval, verify harness can activate tool use:
1. Create `CALIBRATION_SENTINEL_OK` in fixture dir
2. Canary prompt: "Read the file ./CALIBRATION_SENTINEL_OK and report its exact contents"
3. Run with same flags as organic eval
4. 0 tool calls → write `calibration-result.json` with `{"pass": false}` + diagnostic message → stop
5. >=1 tool call → write `calibration-result.json` with `{"pass": true}` → proceed

Store calibration output in `.scratch/<session>/calibration/<unit>/` (outside benchmark dir — prevents `aggregate_benchmark.py` interference).

## Eval execution

### ID validation

Before creating any output dirs, read `evals_json_path` and validate every `evals[*].id` is an integer. Fail with clear error listing offending IDs if not.

### Output layout

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

### eval_metadata.json

Write at `eval-<id>/` level:
```json
{"eval_id": 1, "eval_name": "descriptive name from prompt", "prompt": "the full prompt text", "expectations": ["assertion 1", "assertion 2"]}
```
For each variant run, write IDENTICAL content at `<variant>/run-1/eval_metadata.json`. Two explicit write operations — not a copy.

### Running variants

Per (variant x eval) combination:
```sh
unset CLAUDECODE                    # macOS nested session fix — ALWAYS include
claude -p \
    --model ${model:-sonnet} \
    --output-format stream-json \
    --dangerously-skip-permissions \
    --tools default \
    --verbose \
    --append-system-prompt "$(cat variant-skill.md)" \
    --add-dir "$FIXTURE_DIR" \
    < eval-prompt.md \
    > outputs/output.jsonl
```

Required flags:
- `--dangerously-skip-permissions` — auto-approves all tool use; model avoids tools in `-p` mode without it
- `--tools default` — full built-in tool set including Agent for subagent dispatch
- `--output-format stream-json` — captures tool calls, agent dispatches, and text output for extraction
- `--append-system-prompt` — append skill variant to default system prompt; preserves Claude Code's behavioral instructions (tool-use guidance, agentic priming). Do NOT use `--system-prompt` — it replaces the default prompt, stripping behavioral instructions and causing zero tool calls
- `--add-dir` — give the model access to test fixture files so Read/Grep/Glob work on real paths
- No `--max-budget-usd` — dispatch workflows need multiple turns; budget caps truncate before synthesis completes

## Metrics extraction

### timing.json

Write at `<variant>/run-1/timing.json`:
```json
{"total_duration_seconds": 165.0, "total_tokens": 8450}
```
Capture from subagent task notification. Convert `duration_ms / 1000` → `total_duration_seconds`. These values are NOT persisted elsewhere — extract before the task handle is lost.

### metrics.json

Parse `stream-json` output into `<variant>/run-1/metrics.json` (NOT inside `outputs/`):
```json
{
  "tool_calls": {"Read": 5, "Write": 2, "Bash": 8},
  "total_tool_calls": 15,
  "total_steps": 6,
  "files_created": [],
  "errors_encountered": 0,
  "output_chars": 12450,
  "transcript_chars": 3200,
  "agent_dispatches": 2,
  "timing_ms": 165000,
  "token_usage": {"input": 5000, "output": 3450}
}
```

Generated shell scripts MUST use `#!/bin/sh` — macOS ships bash 3.2.

## Output

Write all output to `benchmark_dir`:
- `eval-<id>/eval_metadata.json` — eval-level metadata
- `eval-<id>/<variant>/run-1/eval_metadata.json` — identical copy per variant run
- `eval-<id>/<variant>/run-1/outputs/output.jsonl` — raw stream-json
- `eval-<id>/<variant>/run-1/metrics.json` — extracted metrics
- `eval-<id>/<variant>/run-1/timing.json` — duration and token totals

## Anti-Patterns

- Using `--system-prompt` instead of `--append-system-prompt` — strips behavioral instructions
- Skipping calibration for tool-dependent skills — zero-tool failures are indistinguishable from skill quality issues
- Storing calibration results inside benchmark directory — `aggregate_benchmark.py` would include them
- Using `declare -A` or bash 4+ features — macOS ships bash 3.2
- Dynamic code execution (`eval`, `python3 -c "...eval..."`) — triggers security hooks; use JSON files
- Setting `--max-budget-usd` on dispatch-heavy skills — truncates workflow before synthesis
- Omitting `unset CLAUDECODE` — nested session detection breaks `claude -p`
- Creating `eval-<id>/` with non-integer ID — aggregate_benchmark.py expects integer directory names
- output.jsonl must be at `outputs/output.jsonl` — `generate_review.py` requires this exact path
- Placing metrics.json inside `outputs/` — breaks METADATA_FILES exclusion in aggregate_benchmark.py
