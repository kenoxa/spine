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

**OpenCode Go**: Marketing page (opencode.ai/go) claims zero retention, no training, US/EU/Singapore. Formal privacy policy is less specific. Backend models (GLM-5, MiniMax M2.5/M2.7, Kimi K2.5) are from Chinese-parent providers routed through OpenCode's infrastructure.

**OpenCode Free (Zen)**: Free models (qwen3.6-plus-free, minimax-m2.5-free, mimo-v2-pro-free) may collect data during preview periods. Privacy policies of underlying model providers apply.

**Cursor**: No per-request data handling documentation. Company-paid with monthly budget. Composer-2 (based on Kimi K2.5) routed through Cursor's infrastructure.

## China Jurisdiction Note

Some OpenCode backend models (GLM from Zhipu/Z.ai, MiniMax, Kimi from Moonshot) are from Chinese-parent companies subject to China's National Intelligence Law (Art. 7). OpenCode Go's US/EU/Singapore infrastructure provides practical distance but not absolute isolation.

## Sources

Primary source policy documents fetched 2026-04-01. Policies change — re-verify at next curation cycle.
