---
updated: 2026-04-01
---

# Copilot CLI Model Plan Gates

Copilot CLI model availability is plan-gated. Not all models listed in GitHub docs are selectable via `--model` flag.

## Gate by Plan

| Plan | Available models |
|------|-----------------|
| Free / Pro | Claude (Sonnet 4.6, 4.5, Haiku 4.5, Opus 4.6/4.5, Sonnet 4), GPT (5.4, 5.3-Codex, 5.2, 5.1*, 5.4 mini, 4.1) |
| Pro+ / Business / Enterprise | + Gemini (3.1 Pro, 3 Flash, 2.5 Pro), Grok, additional models |

Gated models appear in the "Upgrade" tab of the Copilot TUI model selector. Attempting a gated model via CLI returns `Error: Model "X" from --model flag is not available` — indistinguishable from an invalid model name.

## Verification

Tested 8 Gemini name variants (`gemini-3.1-pro`, `gemini-3-pro`, `gemini-3-flash`, `gemini-2.5-pro`, `google/gemini-3.1-pro`, etc.) on a Pro plan — all returned "not available." E3 confirmed.

## Envoy Implication

The `gemini` pseudo-provider routes through Copilot CLI. `check-gemini.sh` probes model availability and correctly fails on Free/Pro plans, falling through to the next available provider. Users who upgrade their Copilot plan get Gemini automatically.
