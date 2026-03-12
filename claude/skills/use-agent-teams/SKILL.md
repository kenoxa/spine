---
name: use-agent-teams
description: >
  Upgrades subagent dispatch to Agent Teams for do-plan, do-execute, and do-discuss phases.
  Use when running do-plan, do-execute, or do-discuss at standard/deep depth.
metadata:
  internal: true
---

Overlay that replaces Spine's parallel subagent dispatch with Agent Teams for 5 phases.

All teammate personas MUST be defined inline in the spawn prompt — custom `.claude/agents/`
files are silently ignored for team agents.

**Lifecycle per phase**: create team → spawn teammates → wait for outputs and peer exchange → synthesize → shut down team. One team per phase; shut down before creating the next.

**Spawn type**: Use the custom agent type matching the phase's dispatch table (`@framer`, `@planner`, `@debater`, `@analyst`, `@inspector`, `@implementer`). If a custom agent type is unavailable, fall back to `general-purpose`. Team agents write output to `.scratch/<session>/`.

Use `team_name` matching the phase: `discuss-explore`, `plan-planning`, `plan-challenge`, `exec-polish`, `exec-review`.

**Augmented teammates**: When variance analysis adds augmented agents, spawn them as additional teammates. Derive inline persona from the lens focus directive (becomes the teammate's framing stance). Generate a peer directive that complements — never contradicts — base teammate directives. Augmented teammates participate in peer exchange on equal footing. All teammates (base + augmented) spawn before any peer exchange begins.

## do-discuss Phase 5: Explore

Create one team.

| Teammate | Peer directive |
|----------|---------------|
| `stakeholder-advocate` | Surface user needs and adoption friction. When peers raise technical concerns, assess user impact. |
| `systems-thinker` | Map dependencies and second-order effects. When peers surface needs, assess feasibility and coupling. |
| `skeptic` | Challenge assumptions and demand evidence. When peers agree, ask "what if that assumption is wrong?" |

Lead reads all teammate outputs + peer messages. Irreconcilable positions become Key Decisions in the problem frame. Convergent findings become Known Facts.

---

## do-plan Phase 3: Planning

Create one team. Lead copies each persona from do-plan's dispatch table and appends the peer directive below:

| Teammate | Peer directive |
|----------|---------------|
| `conservative` | Share concerns about risk and blast radius with peers as you find them. |
| `thorough` | When a peer raises a concern, verify whether your plan addresses it. |
| `innovative` | React to conservative concerns by showing how innovations mitigate or accept them. |

Lead dispatches `@synthesizer` with all teammate outputs + peer exchange. Reads synthesis output (`.scratch/<session>/plan-synthesis-planning.md`) for canonical_plan.

---

## do-plan Phase 4: Challenge Debate

Create one team.

| Teammate | Peer directive |
|----------|---------------|
| `thesis-champion` | When the dissenter raises an objection, respond with specific evidence and steelmanned rebuttals. Do not concede without E2+ counter-evidence. |
| `counterpoint-dissenter` | Read the champion's defenses and escalate with stronger evidence or concede explicitly when rebutted. |
| `tradeoff-analyst` | Track which arguments have been resolved vs remain contested. Quantify costs and reversibility for each open point. |

Lead dispatches `@synthesizer` with all teammate outputs + full peer exchange. Reads synthesis output (`.scratch/<session>/plan-synthesis-challenge.md`). Findings that survive (E2+ with no viable alternative) are incorporated.

---

## do-execute Phase 3: Polish Advisory

Create one team. Lead copies each persona from do-execute's dispatch table and appends:

| Teammate | Peer directive |
|----------|---------------|
| `conventions-advisor` | Share findings with peers so they can check for related implications. |
| `complexity-advisor` | When the conventions advisor flags a pattern, check whether it also has complexity implications. |
| `efficiency-advisor` | When peers flag a pattern deviation or bloat, check whether it also has performance or reuse implications. |

Lead dispatches `@synthesizer` with all teammate outputs + peer messages. Reads synthesis output (`.scratch/<session>/execute-synthesis-polish.md`).

---

## do-execute Phase 4: Adversarial Review

Create one team:

| Teammate | Peer directive |
|----------|---------------|
| `spec-reviewer` | Share spec gaps with peers so they can probe deeper. |
| `correctness-reviewer` | When the spec reviewer flags a gap, check whether it causes correctness issues. |
| `risk-reviewer` | React to correctness findings by assessing their risk severity. |

Lead dispatches `@synthesizer` with all teammate outputs + peer messages. Reads synthesis output (`.scratch/<session>/execute-synthesis-review.md`). Assigns final E-levels and severity buckets per run-review rules.

## Excluded Phases

All other phases: use standard subagent dispatch from Spine skill files.

## Anti-Patterns

- Using delegate mode — always use default mode (delegate breaks tool access)
- Forgetting to shut down a team before creating the next phase's team
