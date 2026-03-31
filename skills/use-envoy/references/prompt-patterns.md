# Prompt Patterns — Rationale

Documents why each line in `prompt-footer.md` exists. This file is for human reference during authoring — it is NOT loaded by the envoy agent.

## Abstain Permission

> If uncertain about any claim, say so rather than speculate.

Reduces hallucination across all providers. Gives the model explicit permission to decline rather than fabricate. Cross-model effective — GPT, Claude, Qwen, DeepSeek all respond to this framing.

## Persistence Instruction

> Complete your full analysis. Do not truncate or summarize prematurely.

Some providers cut output short on long tasks. This line counteracts premature summarization. Particularly effective on models with lower default max output tokens.

## Format Reminder

> Reminder: follow the output format specified above.

Recency bias — models weight end-of-prompt instructions more heavily. Repeating format requirements at the end of the prompt (after all content) significantly improves format compliance. Proven cross-model technique from GPT-4.1 prompting guide and practitioner consensus.
