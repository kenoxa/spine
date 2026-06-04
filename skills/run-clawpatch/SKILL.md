---
name: run-clawpatch
description: >-
  Use when: 'clawpatch', 'clawpatch campaign', 'clawpatch review fix revalidate'.
argument-hint: "[status | --since <ref> | --days <n> | --last-run | --all-open] [--jobs <n>] [--include-dirty] [--local-only]"
---

Drive an async Clawpatch **review → classify → fix → revalidate** campaign over the `clawpatch` CLI. Stateful and explicit — never automatic for every task; activates only on clawpatch-specific intent. Mainthread orchestrates the CLI loop directly (clawpatch holds `.clawpatch/` claim/fix locks — do NOT fan findings out to parallel agents).

This skill assumes a working `clawpatch` install (0.4.0+) with `.clawpatch/` already initialized. It makes no provider/model/feature assumptions — those live in the project's own `clawpatch.config.json`.

## Usage — direct preflight vs `/goal` campaign

- **Direct `/run-clawpatch status`** (or `--local-only` for a bounded local run) — preflight only: `clawpatch doctor` + `status` + dry-run preview. Read-only, safe without a worktree, pauses normally for the user.
- **Recommended full campaign — `/goal /run-clawpatch --since <ref>`.** `/goal` installs the session Stop hook so the agent works the whole review/fix/revalidate loop autonomously without interrupting the user. Under `/goal`, every user-STOP gate below becomes an **emit-artifact-and-halt** signal (write the final report, stop — no autonomous re-launch).

## Phase table

**Backticked refs here are mainthread-read, not dispatched.** This skill spawns no subagents — Read each phase reference with the Read tool **on phase entry** (lazy; do not pre-load all five). That inverts the usual backticked-ref convention (subagent-only, never mainthread-Read; see run-debug, run-curate) because there is no subagent to consume them.

| # | Phase | Action | Reference (Read on entry) |
|---|-------|--------|---------------------------|
| 1 | Preflight | `clawpatch doctor` + `clawpatch status`; record dirty flag + open-finding count; confirm initialized | — (inline) |
| 2 | Scope | resolve scope args → a `--since <ref>` (or unscoped); collect changed paths | `references/scope-resolution.md` |
| 3 | Worktree + session | isolated worktree + `/use-session attach` **before any `.clawpatch` state change** (skip only if `--local-only`) | `references/worktree-session.md` |
| 4 | Ownership | map changed paths → manual `*_manual.json` features; add missing owned files or create a new feature; **halt on ambiguous ownership** | `references/feature-ownership.md` |
| 5–6 | Review + finding loop | `clawpatch review` (scoped per feature, or bounded); then per finding: `next → show → classify → fix+revalidate / triage / leave-open` | `references/finding-loop.md` |
| 7 | Final report | final `revalidate --all --status open` (or scoped); write the report artifact | `references/final-report.md` |

Direct `status` invocation runs Phase 1 only and stops.

## Argument contract

**Scope selectors** (pick one; precedence `--since` > `--days` > `--last-run` > `--all-open`; default `--last-run`):

| Arg | Meaning |
|-----|---------|
| `--since <ref>` | surface changed since a git ref (`main`, a sha) |
| `--days <n>` | surface changed in the last n days |
| `--last-run` | since the last Clawpatch run (newest `.clawpatch/reports/*` mtime → ref) |
| `--all-open` | all open findings, unscoped (triage/revalidate sweep) |

**Knobs:** `--jobs <n>` (review parallelism, default 3) · `--include-dirty` (explicit opt-in to uncommitted changes; else a dirty tree is a stop) · `--local-only`/`--no-commit` (preflight + local edits, no worktree/commit) · `--rate-limit <n>` (→ `--rate-limit-per-minute` / `CLAWPATCH_RPM`) · `--feature <id>` (scope to one feature).

## Halt signals (stop, emit final report, do not re-launch)

- Still on `main` after worktree setup (campaign mode, not `--local-only`).
- Ambiguous feature ownership a generic repo can't resolve.
- Dirty tree without `--include-dirty`.
- Scope needs project-specific metadata absent in this repo.
- 5 consecutive revalidation failures.
- `clawpatch` missing / not initialized / provider unconfigured (preflight fails).

## Anti-Patterns

- Calling any `/run-*` skill (no-run-cycle invariant) — compose via `/goal`, never an internal skill call.
- `clawpatch map`, `init --force`, or re-seeding features unsupervised — flips manual features and floods scratch-derived ones.
- Auto-pruning or status-flipping any `source: manual-*` feature — manual features are the source of truth; halt on ambiguity instead.
- Treating `review --since` as coverage proof — it is selection only; reconcile ownership explicitly.
- Marking a fix done without a green `revalidate` run.
- Committing on `main`; pushing, opening PRs, landing, merging, or deleting/cleaning the branch without an explicit request.
- Running the campaign automatically for every task — it is explicit and stateful.
- Assuming a provider or model (e.g. a specific `codex`/`gpt-5.5` pin is project-specific, not generic).

## Completion

Done when the last review yields 0 new open findings OR every remaining open item has a recorded stop reason; every changed path is owned or documented uncertain; every fix has green-run revalidation (E3: run id + exit) and every triage has evidence; the worktree branch holds commit checkpoints (feature-map changes and verified fix groups), left unpushed/unmerged for human review unless the user requested otherwise. The final report (`references/final-report.md`) is the DONE/STOP evidence artifact.
