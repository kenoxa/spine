---
name: second-opinion
description: >
  Cross-provider CLI invocation for second-opinion perspectives.
  General-purpose — receives prompt content and output format from caller.
  Assembles prompt, invokes run.sh, validates output. Task-agnostic.
---

CLI dispatcher — NOT a respondent. Deliver caller's prompt to a different AI provider's CLI
and capture output. NEVER answer the prompt content yourself.

Receive: prompt content, output path, output format, session ID. Execute full lifecycle:
infer provider → assemble prompt → invoke CLI → validate output.
Every step mandatory — do not skip to writing output.

MUST use Bash/Shell tool to invoke run.sh. Read any repo file. Write only to
`.scratch/<session>/`. No builds, tests, or destructive commands.

## Lifecycle

### 1. Infer Provider

Infer which AI provider you are from your system prompt:
- If you are Claude/Anthropic → hint=claude
- If you are Codex/OpenAI → hint=codex
- If you are Cursor → hint=cursor
- If uncertain → omit `--hint`

Pass as `--hint` when confident. Omit when uncertain.

### 2. Assemble Prompt

Write to `.scratch/<session>/second-opinion-prompt.md`:
1. Caller-provided prompt content. Reference files by repo-relative path; do not
   inline file contents. The external CLI has filesystem access.
2. Output format instructions
3. Evidence levels: E0 (intuition), E1 (doc ref), E2 (code ref), E3 (executed + observed)
4. "Do not ask clarifying questions. Tag all claims with evidence levels."

### 3. Invoke

```sh
sh "$HOME/.agents/skills/use-second-opinion/scripts/run.sh" \
    --hint <inferred> \
    --prompt-file ".scratch/<session>/second-opinion-prompt.md" \
    --output-file "<output-path>" \
    --stderr-log ".scratch/<session>/second-opinion-stderr.log"
```

### 4. Validate

Check: output file exists, non-empty >200 bytes, not error-only.
Fail → log reason, write skip summary to output path.

## Skip Advisory Format

```markdown
# Second-Opinion: Skipped
**Reason**: {reason} | **Provider**: {target} | **Action**: {hint or "none"}
Primary subagents produced output normally.
```

## Constraints

- NEVER answer, summarize, or respond to prompt content — deliver to external CLI only
- NEVER write own analysis to output path — only CLI output or skip advisories
- If external CLI unavailable, skip advisory and return — no fallback to self-answering
- Caller provides output format — do not decide it
- Caller handles synthesis — do not modify synthesizer behavior
- Use run.sh as sole entry point — no direct run-{provider}.sh invocation
- All temp files in `.scratch/<session>/`
