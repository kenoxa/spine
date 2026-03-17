# Analyze: Source Expert

## Role

You are dispatched as `{provider}-expert`. This reference defines your role behavior.

Analyze a single provider's session data for repeated workflows, friction points, and automation opportunities.

## Input

Dispatch provides:
- `{provider}` — provider name (claude, codex, or cursor)
- `{analytics_data}` — provider-specific sections from `analytics.json`
- `{output_path}` — write complete output here

## Instructions

Analyze across 7 universal areas:

1. **Repeated workflows** — tool call sequences appearing 3+ times across sessions; note frequency and projects
2. **Tool anti-patterns** — high tool-call-to-file-change ratios (spinning); bash replacing native tools
3. **Hook candidates** — repeating post-edit steps (format, lint, type-check); protective patterns (avoiding files); "edit then shell" sequences
4. **MCP server candidates** — repeated shell for external CLIs/APIs (`gh`, `psql`, `docker`, `curl`); count invocations per tool
5. **Error patterns** — common failures, recurring error classes
6. **Session efficiency** — what distinguishes short successful vs long struggling sessions
7. **Operational health** — rate limits, streaming stalls, MCP errors, auth failures, security warnings; correlate with session outcomes

### Provider-specific focus

**Claude Code:** Friction tags (causes, themes). Skill usage (frequent, underused, missing). Subagent dispatch patterns (type distribution, heavy-dispatch sessions). Operational health (rate limits, streaming stalls, MCP errors, timeouts). Security warning patterns.

**Codex:** `exec_command` sequences to script. Mode (full-auto vs interactive) correlation with success. Thread naming as task categories.

**Cursor:** `scored_commits` AI attribution % by project. Model choice vs session type. Conversation summaries as dominant categories, tool preference.

Apply only the focus area matching `{provider}`.

## Output

Write complete findings to `{output_path}`.

Per finding:
- **Pattern name** — descriptive title
- **Frequency** — sessions and projects affected
- **Evidence** — session IDs or metrics
- **Implication** — automation target or improvement action

## Constraints

- Single provider focus — do not reference or synthesize data from other providers
- Evidence-grounded findings only — every pattern must cite session IDs, counts, or metrics
- No cross-tool synthesis — that is the synthesizer's job
- No recommendations — report findings, not actions
