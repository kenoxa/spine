---
name: use-agent-teams
description: >
  Upgrades subagent dispatch to Agent Teams for do-plan and do-execute phases.
  Use when running do-plan or do-execute at standard/deep depth.
metadata:
  internal: true
---

Overlay that replaces Spine's parallel subagent dispatch with Agent Teams for 4 phases.

All teammate personas MUST be defined inline in the spawn prompt — custom `.claude/agents/`
files are silently ignored for team agents.

**Lifecycle per phase**: create team → spawn teammates → wait for outputs and peer exchange → synthesize → shut down team. One team per phase; shut down before creating the next.

**Spawn type**: All team agents in all four phases MUST be spawned as `general-purpose` type (not `Explore`). Team agents write output to `.agents/scratch/<session>/`.

Use `team_name` matching the phase: `plan-planning`, `plan-challenge`, `exec-polish`, `exec-review`.

## do-plan Phase 3: Planning

Create one team. Lead copies each persona from do-plan's dispatch table and appends the peer directive below:

| Teammate | Peer directive |
|----------|---------------|
| `conservative` | Share concerns about risk and blast radius with peers as you find them. |
| `thorough` | When a peer raises a concern, verify whether your plan addresses it. |
| `innovative` | React to conservative concerns by showing how innovations mitigate or accept them. |

Lead merges teammate outputs + peer message history into `canonical_plan`.

---

## do-plan Phase 4: Challenge Debate

Create one team. Socratic dialogue, not independent position papers — debaters react to each other's arguments mid-flight.

| Teammate | Peer directive |
|----------|---------------|
| `thesis-champion` | When the dissenter raises an objection, respond with specific evidence and steelmanned rebuttals. Do not concede without E2+ counter-evidence. |
| `counterpoint-dissenter` | Read the champion's defenses and escalate with stronger evidence or concede explicitly when rebutted. |
| `tradeoff-analyst` | Track which arguments have been resolved vs remain contested. Quantify costs and reversibility for each open point. |

Lead reads all teammate outputs + full peer exchange. Findings that survive (E2+ with no viable alternative) are incorporated.

---

## do-execute Phase 3: Polish Advisory

Create one team. Lead copies each persona from do-execute's dispatch table and appends:

| Teammate | Peer directive |
|----------|---------------|
| `conventions-advisor` | Share findings with peers so they can check for related implications. |
| `complexity-advisor` | When the conventions advisor flags a pattern, check whether it also has complexity implications. |

Lead reads both teammate outputs + peer messages. Deduplicates, assigns E-levels.

---

## do-execute Phase 4: Adversarial Review

Create one team:

| Teammate | Peer directive |
|----------|---------------|
| `spec-reviewer` | Share spec gaps with peers so they can probe deeper. |
| `correctness-reviewer` | When the spec reviewer flags a gap, check whether it causes correctness issues. |
| `risk-reviewer` | React to correctness findings by assessing their risk severity. |

Lead reads all teammate outputs + peer messages. Deduplicates, assigns final E-levels and severity buckets per do-review rules.

## Excluded Phases

All other phases: use standard subagent dispatch from Spine skill files.

## Anti-Patterns

- Creating teams for main-thread-only or single-subagent phases
- Using delegate mode — always use default mode (delegate breaks tool access)
- Spawning teams when env var is unset
- Defining teammate personas only via .claude/agents/ files (silently ignored — inline only)
- Forgetting to shut down a team before creating the next phase's team
