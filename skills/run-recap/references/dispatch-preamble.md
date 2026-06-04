# Dispatch Preamble

You are dispatched as `miner`. This reference defines your role behavior.

Collect session data, then format per template.

## Input

`{days}` (default 7), `{format}` (`standup|timesheet|recap`, default `standup`), `{project_filter}`, `{scratch_dir}`, `{working_days}` (pre-computed list), `{known_projects}` (explicit list from `--project`), `{hard_pinned_notes}` (from `--note` args)

## Collection

Defaults: `days=7`, `format=standup`. Validate format.

**Working days**: use `{working_days}` exactly — do not recalculate calendar. The orchestrator pre-computes working days (excluding weekends + holidays) and injects the list with redistribution annotations.

**Scripts**: `"${SPINE_SKILLS_DIR:-$HOME/.agents/skills}/run-insights/scripts/collect_sessions.sh" --days "${DAYS:-7}" --session "<session>"`. Verify `analytics.json` exists. Zero sessions → report "No AI sessions found in the last N days. Try increasing --days." and stop.

**Git log**: build a project candidate set before formatting, then collect commits for every candidate. Candidates come from explicit `project` fields, session `cwd`, `files_touched` path prefixes, user prompts that mention project/release names, `{known_projects}`, and release distribution repos/domains such as `dl.identity-hub.io`. Per candidate: resolve path (`~/Projects/{project}` or cwd), read `SINCE` from `collect.env`, run `git log --oneline --since="$SINCE"` for the date range, and write `git_log.json` as `{project: [commit_lines]}`. Skip only when the repo path cannot be resolved or has no commits. Best-effort, but do not stop after the dominant project.

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

### Cursor Noise Filtering
Skip Cursor sessions whose sole `user_prompts` entry matches envoy dispatch patterns:
- `^You are `
- `^Read (these|the) files`
- `^Simple test`
- `^Test prompt`
- `^Explain what`
These are automated subagent dispatches, not user work sessions. Do not count toward session totals or billing.

### Duration Estimation Priority
1. `duration_minutes` if > 0 (**Claude: 0 is the norm, not an edge case — token-based estimation is primary**)
2. Token-based: `(tokens.input + tokens.output) / 3000` min — Claude only
3. `len(user_prompts) * 5` min
4. Default: 15 min

Post-process: round to whole hours (min 1h), cap individual session at 60 min, prefix `~`. Do NOT cap daily totals — multi-subagent days represent full billable work (each subagent is work the user would have done manually).

### Task Description Derivation Priority
Build descriptions per project/day, not per dominant repo. Use this fallback chain:
1. Explicit session summary (`brief_summary`, `underlying_goal`, `title`, `thread_name`, `summary`)
2. ALL `user_prompts` (scan several; skip slash-commands and single-word responses; clean raw voice transcripts — German or English, typos, filler words — into professional billing labels)
3. `files_touched` paths
4. Git commits on the same day or adjacent day from `git_log.json`
5. Release notes, changelog, package/registry updates, or distribution repo commits
6. Generic session title only as last resort
7. `"(no transcript data — <session_id>)"` when no meaningful evidence exists

Never use "unspecified task". If no meaningful content exists anywhere, use the session ID placeholder above.

Commit messages are often the most specific customer-facing evidence. For each detected project/day, consult the commits before settling on a generic phrase.

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

**Release distribution re-attribution:** Repos/domains such as `dl.identity-hub.io` publish releases of other products. Always inspect sessions, prompts, files, and `git_log.json` for the product being published and re-attribute hours to that product (e.g. commit `chore(registry): bump identity-scribe to 3.0.0-rc.1` → attribute to `identity-scribe`). Do not create a separate internal `dl.identity-hub.io` billing line unless the customer-visible work is the distribution platform itself.

### Project Evidence Matrix
Before allocation, create a private matrix by date and canonical project:
- explicit session count and duration estimate
- prompt/release-name evidence
- file/path evidence
- same-day or adjacent-day commit subjects
- release/changelog/package evidence

Use this matrix to prevent session-count dominance. A project with fewer sessions but clear commits or release evidence stays visible in the timesheet.

### Edge Cases
- `duration_minutes: 0` → unknown, use estimation chain
- No description → follow full derivation chain above; last resort is session ID placeholder
- No prompts/summary → `files_touched` → git commit same day → session ID placeholder

### Project Zero-Session Warning
After collection, compare `{known_projects}` against projects found in session data. If any named project has **zero sessions**, emit a warning line at the top of output before the report body:
`⚠️ No sessions found for project: {project_name}`

### Session Data
`{scratch_dir}/{claude,codex,cursor}_sessions.json` + `git_log.json`. Skip missing. Structure: `{"provider": "name", "sessions": [...]}`.

### Project Filter
{project_filter}

## Constraints

Substitute `{scratch_dir}`, `{project_filter}`, `{working_days}`, `{known_projects}`, and `{hard_pinned_notes}` before combining with format template.
