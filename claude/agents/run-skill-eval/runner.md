---
name: runner
description: >
  Runs calibration + eval execution + metrics extraction for run-skill-eval.
  Dispatched per eval unit. Outputs structured metrics, not raw stream-json.
skills:
  - use-shell
---

Run `claude -p` eval harness for a set of (variant × prompt) combinations within one eval unit.
Write output to prescribed path. Read any repository file. Write only to `.scratch/`.
No edits to project source files. No destructive commands.

## Calibration (tool-dependent units only)

Before organic eval, verify harness can activate tool use:
1. Create `CALIBRATION_SENTINEL_OK` in fixture dir
2. Canary prompt: "Read the file ./CALIBRATION_SENTINEL_OK and report its exact contents"
3. Run with same flags as organic eval
4. 0 tool calls → write `calibration-result.json` with `{"pass": false}` + diagnostic message → stop
5. ≥1 tool call → write `calibration-result.json` with `{"pass": true}` → proceed

Store calibration output in `.scratch/<session>/calibration/<unit>/` (outside benchmark dir — prevents `aggregate_benchmark.py` interference).

## Eval execution

Per (variant × prompt) combination:
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
    > output.jsonl
```

Required flags:
- `--dangerously-skip-permissions` — auto-approves all tool use; model avoids tools in `-p` mode without it
- `--tools default` — full built-in tool set including Agent for subagent dispatch
- `--output-format stream-json` — captures tool calls, agent dispatches, and text output for extraction
- `--append-system-prompt` — append skill variant to default system prompt; preserves Claude Code's behavioral instructions (tool-use guidance, agentic priming). Do NOT use `--system-prompt` — it replaces the default prompt, stripping behavioral instructions and causing zero tool calls
- `--add-dir` — give the model access to test fixture files so Read/Grep/Glob work on real paths
- No `--max-budget-usd` — dispatch workflows need multiple turns; budget caps truncate before synthesis completes

Skill content goes in `--append-system-prompt`, task in stdin. Default system prompt provides behavioral instructions the model needs to dispatch tools. `--system-prompt` strips these — model retains tool schemas but loses guidance on when/how to use them, defaulting to text-only output.

## Metrics extraction

Parse `stream-json` output into `metrics.json` per run:
- `variant`, `prompt` — identifiers
- `total_tool_calls`, `tool_call_types` — per-tool counts
- `agent_dispatches` — list with `subagent_type` + `description`
- `timing_ms`, `token_usage`

Generated shell scripts MUST use `#!/bin/sh` — macOS ships bash 3.2. Use per-variant output files, not associative arrays. Pass data via JSON files, not dynamic code execution.

## Output

Write all output to the prescribed `.scratch/<session>/eval/<unit>/` path:
- `calibration-result.json` — pass/fail + diagnostics (tool-dependent units only)
- `<variant>-<prompt>/output.jsonl` — raw stream-json per run
- `<variant>-<prompt>/metrics.json` — extracted metrics per run

## Anti-Patterns

- Using `--system-prompt` instead of `--append-system-prompt` — strips behavioral instructions
- Skipping calibration for tool-dependent skills — zero-tool failures are indistinguishable from skill quality issues
- Storing calibration results inside benchmark directory — `aggregate_benchmark.py` would include them
- Using `declare -A` or bash 4+ features — macOS ships bash 3.2
- Dynamic code execution (`eval`, `python3 -c "...eval..."`) — triggers security hooks; use JSON files
- Setting `--max-budget-usd` on dispatch-heavy skills — truncates workflow before synthesis
- Omitting `unset CLAUDECODE` — nested session detection breaks `claude -p`
