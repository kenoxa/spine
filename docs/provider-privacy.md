---
updated: 2026-04-01
---

# Provider Privacy & Data Handling

Privacy comparison for envoy provider selection. Guides default priority ordering.

## Summary

| Provider | Training on code | Retention | Residency | Compliance |
|----------|-----------------|-----------|-----------|------------|
| Copilot Business/Enterprise | No (DPA) | 0 days (IDE prompts) | US | SOC2, ISO 27001, IP indemnity |
| Alibaba Cloud Dashscope (paid Qwen) | No ("never") | API: not saved | Singapore primary | SOC2, DPA, SCCs |
| MiniMax API | No (explicit) | Deleted after purpose | US | GDPR, SCCs |
| OpenCode Go | No training, zero retention | — | US/EU/Singapore | — |
| Z.ai/GLM (international) | Unclear | API: not stored | Singapore | No SOC2 |
| Copilot Free/Pro/Pro+ | Yes (opt-out, from 2026-04-24) | 28 days (non-IDE) | US | — |
| Qwen free OAuth | Unclear | Not specified | Likely China | Not documented |
| DeepSeek API | Yes (opt-out) | Account lifetime | China (explicit) | Nominal GDPR |

## Key Splits

**Qwen**: paid Dashscope API = strong (explicit no-training, DPA, SOC2, Singapore). Free OAuth tier = weak (consumer service, undocumented, likely China). Sharp difference.

**Copilot**: Business/Enterprise = strongest commercial guarantee. Free/Pro = default opt-in training from April 24, 2026 (GitHub blog, 2026-03-25). Opt-out available.

**OpenCode Go**: Marketing page (opencode.ai/go) claims zero retention, no training, US/EU/Singapore. Formal privacy policy is less specific. MiniMax (standard/fast tier backend) has explicit no-training policy with US data centers.

## China Jurisdiction Note

Chinese-parent providers (Alibaba, Zhipu/Z.ai, MiniMax, DeepSeek) are subject to China's National Intelligence Law (Art. 7) regardless of data residency. Singapore/US entity structures provide practical distance but not absolute isolation.

## Sources

Primary source policy documents fetched 2026-04-01. Policies change — re-verify at next curation cycle.
