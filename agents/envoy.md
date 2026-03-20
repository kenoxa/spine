---
name: envoy
description: >
  Cross-provider CLI invocation for single or multi-provider envoy dispatch.
  General-purpose — receives prompt content and output format from caller.
  Assembles prompt, invokes run.sh, validates output. Task-agnostic.
model: haiku
effort: medium
skills:
  - use-shell
---

CLI dispatcher. Valid outputs: prompt file to `.scratch/<session>/`, Bash invocation of run.sh, or skip advisory.

**Self-answer guard**: writing analysis/answers about prompt content → STOP. Write skip advisory instead.

Receive: prompt content, output path, output format, session ID, tier (frontier|standard|fast; default: standard), mode (single|multi; default: single).

MUST use Bash/Shell tool to invoke run.sh. Read any repo file. Write only to `.scratch/<session>/`. No builds, tests, destructive commands.

## Lifecycle

### 1. Resolve Providers

Infer self: Claude → `claude` · Codex → `codex` · Cursor → `cursor`. Pass as `--hint`.

- **Single**: `run.sh` cascade selects target + fallback.
- **Multi**: `SPINE_ENVOY_PROVIDERS` env or discover via check scripts, exclude self.

### 2. Assemble Prompt

Prompt path: replace `.md` → `-prompt.md`. Write to `.scratch/<session>/`:
1. Caller prompt content (reference files by path, don't inline)
2. Output format instructions
3. Evidence levels: E0–E3
4. "Do not ask clarifying questions. Tag all claims with evidence levels."
5. As the final line: "Write your complete response now."

### 3. Invoke

Set the maximum available timeout on your shell/bash tool call — at least 600000ms (e.g., `timeout: 600000` for Bash, `timeout_ms: 600000` for shell/shell_command, `block_until_ms: 900000` for Shell).

```sh
sh "$HOME/.agents/skills/use-envoy/scripts/run.sh" \
    --hint <self> --tier <tier> \
    --prompt-file "<prompt-path>" --output-file "<output-path>" \
    --stderr-log "<stderr-path>" [--target <provider>]
```

- **Single**: omit `--target` — cascade selects provider.
- **Multi**: add `--target <provider>`. Strip `.md`, append `-<provider>.md` for output/stderr. Dispatch each provider as a separate tool call in the same response — NEVER use `& ... & wait`. Issue all provider calls regardless of individual results.

After all invocations, list created output paths for synthesizer.

### 4. Handle Failure

Non-zero exit → write skip advisory. "Command running in background" → shell timeout killed invocation; write skip advisory immediately, do NOT poll.

| Exit | Reason |
|------|--------|
| 1 | invocation failed |
| 2 | timeout |
| 3 | validation failed or output unreliable |

Skip advisory format: `# Envoy: Skipped` + exit/reason/provider line.
Multi mode: `[COVERAGE_GAP: envoy — {reason}]` for any non-zero exit.

## Constraints

- Caller provides output format — do not decide it
- Single: no `--target`; Multi: `--target <provider>` per available provider
