# Analysis Prompt Templates

## Common Output Format

All source-expert and synthesizer prompts use this finding structure:

- **Pattern name** — descriptive title
- **Frequency** — how many sessions, which projects
- **Evidence** — session IDs or aggregated metrics
- **Implication** — what automation (skill, plugin, agent, rule, or fix) would address this

## Source-Expert Prompt Template

Use this template for all three providers, substituting the provider-specific focus areas below.

```
You are analyzing {provider} session data from the last N days.

Your task: identify repeated workflows, friction points, and automation opportunities.

## Data
{analytics_data}

## Universal analysis areas

1. **Repeated workflows**: Tool call sequences appearing 3+ times across sessions. Note frequency and projects.
2. **Tool anti-patterns**: High tool-call-to-file-change ratios (spinning). Bash commands that could be native tool calls.
3. **Hook candidates**: Manual post-edit steps (formatting, linting, type-checking) that repeat across sessions. Protective patterns (avoiding certain files). Any consistent "edit → shell command" sequence is a hook signal.
4. **MCP server candidates**: Repeated shell commands for external CLIs/APIs (gh, psql, docker, curl to same endpoint). Count invocations per tool across sessions.
5. **Error patterns**: Common failures, recurring error classes across sessions.
6. **Session efficiency**: What distinguishes short successful sessions from long struggling ones?

## Provider-specific focus

{provider_focus}

## Output format

For each finding: pattern name, frequency, evidence, implication. Write your complete output to {output_path}.
```

### Provider-specific focus areas

**Claude Code:**
- Friction tags (wrong_approach, excessive_reading, etc.) — what causes friction? Recurring themes?
- Skill usage: frequently used, underused despite relevant sessions, sessions where a skill would have helped
- Subagent dispatch patterns

**Codex:**
- Command patterns via exec_command — repeated sequences that could be scripted
- Collaboration modes (full-auto vs interactive) — does mode correlate with success?
- Thread naming patterns — do they reveal task categories?

**Cursor:**
- AI attribution from scored_commits — what % is AI-generated vs human? Variation by project?
- Model usage patterns — does model choice correlate with session type?
- Conversation summaries — what task categories dominate? When is Cursor preferred over other tools?

## Synthesizer Prompt

```
You are synthesizing cross-tool session analysis to produce actionable recommendations.

## Source Expert Analyses
{all_expert_outputs}

## Cross-Tool Analytics
{cross_tool_section}
{sample_prompts_section}

## Recommendation Categories

### 1. Skills to Create
Repeated multi-step workflows (stable sequence, varying inputs). Threshold: 3+ occurrences. Cross-tool patterns get priority boost. Include: what it does, prefix (do-/use-/with-), rough structure.

### 2. Hooks to Configure
Automatic actions on tool events. Signal: manual post-edit formatting/linting (e.g., running prettier/eslint after edits), repeated protective checks (avoiding .env files, lock files), consistent post-save validation (type-checks, tests). Include: hook type (PreToolUse/PostToolUse), trigger pattern, command, and the settings.json snippet.

### 3. MCP Servers to Install
External service integrations via MCP protocol. Signal: repeated shell commands for the same CLI/API — e.g., `gh` (→ GitHub MCP), `psql`/`mysql` (→ Database MCP), `curl` to same API (→ context7 or custom MCP), `docker` (→ Docker MCP). Threshold: 3+ shell invocations of the same external tool. Include: server name, install command, what it replaces.

### 4. Plugins to Build
Capabilities requiring external tooling beyond native agent tools. Signal: repeated shell commands for the same CLI/API. Include: what it wraps, inputs/outputs.

### 5. Agents to Define
Self-contained parallelizable tasks. Signal: independent sub-tasks, recurring research/validation. Include: role, model recommendation (haiku for fast, inherit for deep).

### 6. CLAUDE.md / AGENTS.md Rules
Persistent preferences or corrections repeated across sessions. Distinguish project-level vs global. Include: exact rule text.

### 7. Anti-patterns to Address
Behaviors wasting time. Signal: high tool-call-to-change ratio, repeated nudges, same error class. Include: what's happening, root cause, fix.

## Output format

For each recommendation:

## [Category]: [Title]
- **Priority**: high | medium | low
- **Evidence**: [sessions, frequency, tools involved]
- **Action**: [concrete next step]
- **Example**: [draft artifact — skill frontmatter, rule text, agent definition, etc.]

Order by priority within each category. Cross-tool patterns get priority boost.

Write your complete output to {output_path}.
```
