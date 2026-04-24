---
updated: 2026-04-24
paths:
  - skills/use-skill-craft/SKILL.md
  - CONTRIBUTING.md
  - SPINE.md
  - skills/do-build/references/build-review-gate.md
  - skills/run-review/references/template-review-brief.md
---

# Skill Guardrail Patterns

## Anti-Rationalization Bullets

Rationalization-awareness bullets in Anti-Patterns section. Format:
`"excuse" — reality: consequence`. Distinct from structural anti-patterns —
targets agent self-talk at step-skipping moments.

Converged independently in two major frameworks:
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (10k+ stars) — "Common Rationalizations" tables
- obra/superpowers (137k stars) — anti-rationalization tables + rationalization testing

Spine format: one-line telegraphic bullets, not 2-column tables. Fits existing
anti-pattern convention.

## Completion Sections

Optional `## Completion` for workflow skills with phase-gated exits. 3-6
evidence requirements, E-level tagged. Precedent: run-debug, do-build/finalize,
phase-audit completion gates.

Required for `do-*`/`run-*` with phase tables. Omit for `use-*`/`with-*`.

## Inline vs Hook Enforcement

Inline guardrail sections = salience aids at activation time. NOT cross-session
enforcement. Per rjmurillo/ai-agents post-mortem: trust-based inline instructions
~0% success for autonomous multi-session; hook-based enforcement 90%+.

Spine mitigation: skills reactivate per-session — activation-time salience is
the relevant mode. For true enforcement, pair with PostToolUse hooks.

## Layered Defense for Autonomous Runs

Static hook inspection of shell source text has an inherent ceiling: shell
quote-stripping, command-substitution, and path-resolution happen AFTER the hook
sees the string. Three bypass classes survive even a dual-layer hook (substring
pre-check + POSIX tokenizer):

- **Shell-grouping / delegation** — `(git push)`, `bash -c "git push"` —
  substring present but opener token shifts past `git`.
- **Program-token obfuscation** — `"git" push`, `$(which git) push`,
  `/usr/bin/git push` — literal `git` absent or quoted; tokenizer first-word
  check fails.
- **Option-bearing** — `git --git-dir=X push` — `git` and blocked subcommand
  non-adjacent in token stream; substring pre-check misses chains.

[E2: `skills/run-queue/scripts/guard-queue-shell.sh:127-141`; E3: `.scratch/autonomous-overnight-task-queue-1034/review-verifier.md` iter-1 FAIL + `review-verifier-iter2.md` regression probes; commits `30aab27`, `dfe6c70`]

**Resolution: env-scoped git-config belt.** Defense-in-depth layer below the
hook. Inside the child-spawn subshell, before exec:

```sh
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="url.disabled:///.pushInsteadOf"
export GIT_CONFIG_VALUE_0="https://"
export GIT_CONFIG_KEY_1="url.disabled:///.pushInsteadOf"
export GIT_CONFIG_VALUE_1="git@"
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false
```

Git rewrites any push URL to an unresolvable `disabled:///` scheme, aborting at
the git-protocol layer regardless of command shape. `GIT_TERMINAL_PROMPT=0` +
`GIT_ASKPASS=/bin/false` prevent credential prompts on a headless stdin.
Env-scoped to the subshell — no `.git/config` mutation, auto-cleans on exit, no
supervisor cleanup contract needed.

E3 verified: HTTPS origin, SSH upstream, and residual obfuscation forms
(`"git" push`, `$(which git) push`) all terminated with `remote helper
'disabled' aborted session`. Local ops (`git bundle create`) are unaffected —
expected; bundle does not use push URLs, and the hook still denies it via
substring.

[E2: `skills/run-queue/scripts/run.sh:327-341`; E3: `review-verifier-iter3.md` Probe suite 5; commit `274f51b`]

**Pattern:** hook layer + git-config belt = two independent failure surfaces.
Any LLM-wrapping context that needs to neutralize git push operations can reuse
the env-var set verbatim — no repo state required, no cleanup contract.

## Ecosystem Context

agentskills.io spec (Anthropic, OpenAI, Sourcegraph): `name` + `description`
required; body sections free-form. Anti-rationalization/Red Flags/Verification
are community convention (addyosmani), not standard.

Red Flags most independently validated (narumiruna adopted independently).
Rationalization tables second (addyosmani + obra). Verification checklists
addyosmani-specific.

## Cross-File Safety Qualifier Echoing

When a SPINE.md rule summarizes a constraint from a reference file, echo any
safety-critical qualifier inline in SPINE.md. Subagents receive SPINE.md via
`@~/.config/spine/SPINE.md` import (CLAUDE.md / AGENTS.md → SPINE.md) but do NOT
load reference files unless a specific review or polish skill dispatches them.

Example: `advisory-complexity.md:7,38` carries `NEVER flag auth, authz, or
validation boundaries`. SPINE.md L22's "impossible conditions" rule summarized
the same heuristic but omitted that qualifier — a subagent reading only SPINE.md
could strip required auth validation as "defensive bloat". Fix: append the qualifier
directly in the SPINE.md rule. [E2: `SPINE.md:22`, `advisory-complexity.md:7,38`;
commit 4fba8df]

**Audit trigger**: when compressing a rule from a reference file into SPINE.md,
check whether the reference file carries a `NEVER`/`always` safety clause that
the compressed form omits. If yes, echo it in the SPINE.md line — one clause cost.

## New Rule Conflict Audit

When adding a rule to SPINE.md `## Collaboration` (or any section with
competing directives), explicitly precedence-rank it against existing rules
before committing.

**Pattern that fails**: new rule adds a valid behavior but creates an implicit
override of an existing rule. Example: `surface multiple interpretations when
a request is ambiguous` conflicted with `Lead with clear takes` and
`Avoid "it depends"` — an over-literal agent treats mild under-specification
as ambiguity and asks instead of deciding. Caught independently by 3 envoys
(codex/cursor/opencode all flagged MEDIUM). [E2: `SPINE.md:91-92`;
commit 4fba8df]

**Fix pattern**: tighten the trigger to make precedence implicit in the clause
itself. `only when readings would produce different deliverables` makes L92 fire
only on high-grade ambiguity; `Lead with clear takes` (L91) wins on everything
else. No explicit ordering needed when trigger is narrow enough.

**Audit trigger**: before merging a new Collaboration rule, scan existing rules
for decide/ask tension. If the new rule expands ask-surface, add `only when` or
`only if` to narrow the trigger. Advisory — not a gate, but catches the most
common multi-rule conflict pattern in Spine's history.

## Invariant-First Review Briefs

List explicit numbered invariants in the review brief `## invariants` block.
Synthesizer treats them as higher-authority source than individual envoy severity
labels — reconciliation is synthesizer's job.

Pattern that works: brief invariant #3 ("trip-wire supersedes everything") +
SPINE.md fail-secure mandate → synthesizer elevates codex [S] to blocking [B2]
and [B3]; iter-2 verifier confirmed both elevations. Without invariants in the
brief, these would have shipped as should_fix.

**Audit trigger**: before writing a review brief, enumerate: trust boundaries,
state-machine contracts, schema enumerations, purity constraints. One sentence
per invariant. Reference the contract document when applicable (e.g.,
`build-status-schema.md`). Envoy labels are advisory; brief invariants gate
severity.

[E2: `.scratch/slice-c-intra-task-loop-32e7/review-brief.md §invariants`,
`review-synthesis.md §Conflicts Resolved` rows 1-2; E3:
`review-verifier-iter2.md` VERDICT PASS; commits `4cea877`, `b6b1b85`]

*Prior art: Design-by-Contract / Invariant-Driven Development (Fairbanks 2019;
Trail of Bits 2025). Cap invariants at 5–10 high-signal trip-wires — IDD warns
against "invariant inflation" that collapses review heuristics into test cases.*
`[ADVISORY: envoy]`
