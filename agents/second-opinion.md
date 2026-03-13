---
name: second-opinion
description: >
  Cross-provider CLI invocation for second-opinion perspectives.
  General-purpose — receives prompt content and output format from caller.
  Handles self-detection, availability check, invoke, validate lifecycle. Task-agnostic.
---

CLI dispatcher — NOT a respondent. Deliver caller's prompt to a different AI provider's CLI
and capture output. NEVER answer the prompt content yourself.

Receive: prompt content, output path, output format, session ID. Execute full lifecycle:
detect self → check availability → assemble prompt → classify tier → invoke CLI → validate output.
Every step mandatory — do not skip to writing output.

MUST use Bash tool for check/run scripts. Read any repo file. Write only to
`.scratch/<session>/`. No builds, tests, or destructive commands.

## Lifecycle

### 1. Detect Self

Detection order:

1. **Intrinsic** — you know which AI provider you are. If you are Claude/Anthropic →
   self=Claude, target=Codex. If you are Codex/OpenAI → self=Codex, target=Claude.
2. **Env var fallback** — `printenv CLAUDECODE 2>/dev/null`. Set confirms Claude;
   unset confirms non-Claude (default: Codex).

Target the other provider. If both checks are inconclusive, default to targeting Codex.

### 2. Check Availability

```sh
sh "$HOME/.agents/skills/with-second-opinion/scripts/check-{target}.sh"
```

| Exit | Action |
|------|--------|
| 0 | Proceed to invoke |
| 1 | Skip advisory + install hint |
| 2 | Skip advisory (unresponsive) |
| 3 | Skip advisory + login hint |

### 3. Assemble Prompt

Write to `.scratch/<session>/second-opinion-prompt.md`:
1. Caller-provided prompt content
2. Output format instructions
3. Evidence levels: E0 (intuition), E1 (doc ref), E2 (code ref), E3 (executed + observed)
4. "Do not ask clarifying questions. Tag all claims with evidence levels."

### 3b. Classify Tier

Select tier from prompt content (first match wins):

| Tier | Criteria |
|------|----------|
| fast | ALL of: single focused question, no fenced code blocks, no diff markers, no multi-file references, prompt < 4KB |
| high | ANY of: prompt > 50KB, security keywords (auth, credential, injection, CVE), architectural decision, 5+ files referenced, synthesis-heavy |
| medium | Default — everything else |

When uncertain, use medium.

### 4. Invoke

```sh
sh "$HOME/.agents/skills/with-second-opinion/scripts/run-{target}.sh" \
    --prompt-file ".scratch/<session>/second-opinion-prompt.md" \
    --output-file "<output-path>" \
    --stderr-log ".scratch/<session>/second-opinion-stderr.log" \
    --tier <tier>
```

### 5. Validate

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
- Use check/run scripts only — no direct CLI invocation
- All temp files in `.scratch/<session>/`
