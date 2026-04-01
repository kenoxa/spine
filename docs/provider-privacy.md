---
updated: 2026-04-01
---

# Provider Privacy & Data Handling

Privacy comparison for envoy provider selection. Current stack: Claude, Codex, Cursor, OpenCode.

## Summary

| Provider | Training on code | Retention | Residency | Compliance |
|----------|-----------------|-----------|-----------|------------|
| Claude (Anthropic) | No (Enterprise); opt-out available | — | US | SOC2, IP indemnity (Enterprise) |
| Codex (OpenAI) | No (Enterprise); opt-out available | — | US | SOC2, IP indemnity (Enterprise) |
| Cursor | Not documented per-request | — | US | — |
| OpenCode Go | No training, zero retention | — | US/EU/Singapore | — |
| OpenCode Free (Zen) | Varies by underlying model | — | Varies | — |

## Key Splits

**OpenCode Go**: Marketing page (opencode.ai/go) claims zero retention, no training, US/EU/Singapore. Formal privacy policy is less specific. Backend models from Chinese-parent providers (Zhipu/GLM, MiniMax, Moonshot/Kimi) routed through OpenCode's infrastructure.

**OpenCode Free (Zen)**: Free-tier models may collect data during preview periods. Privacy policies of underlying model providers apply.

**Cursor**: Backend model routing not publicly documented per-request. Company-paid with monthly budget.

## China Jurisdiction Note

Some OpenCode backend models (GLM from Zhipu/Z.ai, MiniMax, Kimi from Moonshot) are from Chinese-parent companies subject to China's National Intelligence Law (Art. 7). OpenCode Go's US/EU/Singapore infrastructure provides practical distance but not absolute isolation.

## Sources

Primary source policy documents fetched 2026-04-01. Policies change — re-verify at next curation cycle.
