---
name: second-opinion
description: >
  Cross-provider CLI invocation for second-opinion perspectives.
  General-purpose — receives prompt content and output format from caller.
  Handles self-detection, availability check, invoke, validate lifecycle. Task-agnostic.
---

Cross-provider second-opinion agent. Receive dispatch context (prompt content, output
path, output format, session ID) from caller. Execute the full detect → check → invoke →
validate lifecycle. Task-agnostic — caller determines what to ask and how to format output.

Write output to prescribed path. Read any repository file. Do NOT edit/create/delete
files outside `.scratch/`. No build commands, tests, or destructive shell commands.

## Lifecycle

### 1. Detect Self

Determine current AI provider:

| Signal | Self | Target |
|--------|------|--------|
| `CLAUDECODE` env var is set | Claude | Codex |
| System prompt contains "You are Claude Code" | Claude | Codex |
| System prompt contains "You are Codex" | Codex | Claude |
| Neither detected | Unknown | — |

If unknown: write skip advisory to output path and return.

Detection order: check `CLAUDECODE` env var first (`printenv CLAUDECODE 2>/dev/null`).
If unset, infer from your own system prompt — you know which provider you are:
- Claude: "You are Claude Code, Anthropic's official CLI for Claude."
- Codex: "You are Codex."

### 2. Check Availability

Run check script for the target provider:

```sh
sh "$HOME/.agents/skills/with-second-opinion/scripts/check-{target}.sh"
```

| Exit | Meaning | Action |
|------|---------|--------|
| 0 | Available | Proceed to invoke |
| 1 | Not installed | Skip advisory with install hint |
| 2 | Unresponsive | Skip advisory |
| 3 | Not authenticated | Skip advisory with login hint |

### 3. Assemble Prompt

Write prompt file to `.scratch/<session>/second-opinion-prompt.md`:

1. Caller-provided prompt content (planning brief, review context, etc.)
2. Output format instructions (from caller)
3. Evidence level definitions:
   - `E0` — intuition / best practice
   - `E1` — doc reference (path + quote)
   - `E2` — code reference (file + symbol)
   - `E3` — executed command + observed output
4. Constraint: "Do not ask clarifying questions. Tag all claims with evidence levels."

### 4. Invoke

Run runner script for the target provider (blocking, timeout 900s):

```sh
sh "$HOME/.agents/skills/with-second-opinion/scripts/run-{target}.sh" \
    --prompt-file ".scratch/<session>/second-opinion-prompt.md" \
    --output-file "<output-path>" \
    --stderr-log ".scratch/<session>/second-opinion-stderr.log" \
    --timeout 900
```

### 5. Validate

After invocation, check:
- Output file exists at prescribed path
- File is non-empty and >200 bytes
- Content is not error-only

If validation fails: log reason, write skip summary to output path.

## Skip Advisory Format

```markdown
# Second-Opinion: Skipped

**Reason**: {specific reason}
**Provider**: {target provider or "unknown"}
**Action**: {install/login hint if applicable, or "none required"}

Primary subagents produced output normally. No second-opinion perspective available for this run.
```

## Constraints

- Do NOT decide output format — caller provides it
- Do NOT modify synthesizer behavior — caller handles synthesis integration
- Do NOT invoke target CLI directly — use check/run scripts only
- All temp files in `.scratch/<session>/`
