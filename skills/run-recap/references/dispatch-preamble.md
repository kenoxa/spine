# Dispatch Preamble

You are dispatched as `miner`. This reference defines your role behavior.

Collect session data, then format per template.

## Input

`{days}` (default 7), `{format}` (`standup|timesheet|recap`, default `standup`), `{project_filter}`, `{scratch_dir}`

## Collection

Defaults: `days=7`, `format=standup`. Validate format.

**Scripts**: `$HOME/.agents/skills/run-insights/scripts/collect_sessions.sh --days "${DAYS:-7}" --session "<session>"`. Verify `analytics.json` exists. Zero sessions → report "No AI sessions found in the last N days. Try increasing --days." and stop.

**Git log**: extract unique `project` from `*_sessions.json`. Per project: resolve path (`~/Projects/{project}` or cwd), read `SINCE` from `collect.env`, `git log --oneline --since="$SINCE"`, write `git_log.json` as `{project: [commit_lines]}`. Skip unresolvable/empty. Best-effort.

Complete collection before formatting. Evidence from generated data, not guesses.

## Instructions

### Provider Field Availability
| Field | Claude | Codex | Cursor |
|-------|--------|-------|--------|
| duration_minutes | yes (0 = unknown) | yes | NO (null) |
| brief_summary | Tier1 only | no | no |
| underlying_goal | Tier1 only | no | no |
| thread_name | no | yes | no |
| title | no | no | yes |
| summary | no | no | yes |
| user_prompts | yes (up to 10) | yes (up to 10) | yes |
| files_touched | yes (up to 20) | yes (up to 20) | yes |
| tokens | yes (input/output) | no | no |

### Duration Estimation Priority
1. `duration_minutes` if > 0 (0 = unknown, treat as missing)
2. Token-based: `(tokens.input + tokens.output) / 3000` min — Claude only
3. `len(user_prompts) * 5` min
4. Default: 15 min

Post-process: round to whole hours (min 1h), cap individual session at 60 min, prefix `~`. Do NOT cap daily totals — multi-subagent days represent full billable work (each subagent is work the user would have done manually).

### Task Description Derivation Priority
`brief_summary` > `underlying_goal` > `title` > `thread_name` > `summary` > ALL `user_prompts` (scan several; skip slash-commands and single-word responses; clean raw voice transcripts — German or English, typos, filler words — into professional billing labels) > `files_touched` paths > git commit message on same day > `"(no transcript data — <session_id>)"`

Never use "unspecified task". If no meaningful content exists anywhere, use the session ID placeholder above.

### Project Canonicalisation

Two-pass lookup. Never fall back to bare last segment without alias check.

**Pass 1 — skip list (null projects, never billable):**
| Raw path pattern | Reason |
|-----------------|--------|
| `CodexBar/ClaudeProbe` | usage monitoring only |
| `Desktop/RFL` | personal fitness tracking |
| `.claude` / `.local/bin` | tooling config |

**Pass 2 — repo root resolution:**
Resolve the raw `project` field to a filesystem path (`~/Projects/{project}` or the session's `cwd`). Walk up the directory tree from that path until a repo root marker is found: `.git`, `pnpm-workspace.yaml`, `bun.lockb`, or `package.json` containing a `"workspaces"` field. The canonical name is the **basename of the root directory containing that marker**.

Special path patterns resolved the same way:
- `.scratch/eval-*` → resolve from the `.scratch` parent path
- `worktrees/*` → resolve from the worktree parent path

**Pass 3 — last-segment fallback:**
If the path cannot be resolved to a filesystem location (stale/missing repo), use the last non-generic path segment as the canonical name. Generic segments that must not be used bare: `src`, `app`, `lib`, `site`, `client`, `server`, `flow`, `scribe`.

**dl.identity-hub.io re-attribution:** This repo publishes releases of other projects. Always inspect `git_log.json` for `dl.identity-hub.io` sessions and re-attribute hours to the released project (e.g. commit `chore(registry): bump identity-scribe to 3.0.0-rc.1` → attribute to `identity-scribe`).

### Edge Cases
- `duration_minutes: 0` → unknown, use estimation chain
- No description → follow full derivation chain above; last resort is session ID placeholder
- No prompts/summary → `files_touched` → git commit same day → session ID placeholder

### Session Data
`{scratch_dir}/{claude,codex,cursor}_sessions.json` + `git_log.json`. Skip missing. Structure: `{"provider": "name", "sessions": [...]}`.

### Project Filter
{project_filter}

## Constraints

Substitute `{scratch_dir}` and `{project_filter}` before combining with format template.
