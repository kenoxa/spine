# Analysis Prompt Templates

## Common Output Format

All prompts use this finding structure:
- **Pattern name** — descriptive title
- **Frequency** — sessions, projects
- **Evidence** — session IDs or aggregated metrics
- **Implication** — what automation would address this

## Source-Expert Prompt Template

Use for all three providers, substituting provider-specific focus areas below.

```
Analyze {provider} session data from the last N days. Identify repeated workflows, friction points, and automation opportunities.

## Data
{analytics_data}

## Universal analysis areas
1. **Repeated workflows**: Tool call sequences 3+ times across sessions — note frequency, projects
2. **Tool anti-patterns**: High tool-call-to-file-change ratios (spinning); bash replacing native tools
3. **Hook candidates**: Repeating post-edit steps (format, lint, type-check); protective patterns (avoiding files); "edit → shell" sequences
4. **MCP server candidates**: Repeated shell for external CLIs/APIs (gh, psql, docker, curl) — count invocations per tool
5. **Error patterns**: Common failures, recurring error classes
6. **Session efficiency**: What distinguishes short successful vs long struggling sessions?

## Provider-specific focus
{provider_focus}

## Output format
Per finding: pattern name, frequency, evidence, implication. Write complete output to {output_path}.
```

### Provider-specific focus areas

**Claude Code:** Friction tags (causes, themes). Skill usage (frequent, underused, missing). Subagent dispatch patterns.

**Codex:** exec_command sequences to script. Mode (full-auto vs interactive) correlation with success. Thread naming → task categories.

**Cursor:** scored_commits AI attribution % by project. Model choice vs session type. Conversation summaries → dominant categories, tool preference.

## Synthesizer Prompt

```
Synthesize cross-tool session analysis into actionable recommendations.

## Source Expert Analyses
{all_expert_outputs}

## Cross-Tool Analytics
{cross_tool_section}
{sample_prompts_section}

## Recommendation Categories

### 1. Skills to Create
Repeated multi-step workflows (stable sequence, varying inputs). Threshold: 3+. Cross-tool → priority boost. Include: purpose, prefix (do-/use-/with-), rough structure.
### 2. Hooks to Configure
Signal: manual post-edit formatting/linting, protective checks (.env, lock files), post-save validation. Include: hook type (PreToolUse/PostToolUse), trigger, command, settings.json snippet.
### 3. MCP Servers to Install
Signal: 3+ shell invocations of same external CLI/API (`gh`, `psql`, `docker`, `curl`). Include: server name, install command, what it replaces.
### 4. Plugins to Build
Signal: repeated shell for same CLI/API beyond native tools. Include: what it wraps, inputs/outputs.
### 5. Agents to Define
Signal: independent sub-tasks, recurring research/validation. Include: role, model (haiku for fast, inherit for deep).
### 6. CLAUDE.md / AGENTS.md Rules
Persistent preferences/corrections across sessions. Project-level vs global. Include: exact rule text.
### 7. Anti-patterns to Address
Signal: high tool-call-to-change ratio, repeated nudges, same error class. Include: what's happening, root cause, fix.

## Output format
Per recommendation:

## [Category]: [Title]
- **Priority**: high | medium | low
- **Evidence**: [sessions, frequency, tools]
- **Action**: [concrete next step]
- **Example**: [draft artifact — skill frontmatter, rule text, agent definition, etc.]

Order by priority within category. Cross-tool → priority boost. Write complete output to {output_path}.
```
