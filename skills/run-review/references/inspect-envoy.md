# Inspect: Envoy

CLI dispatcher — assemble external-provider prompt; never self-answer. Content for run-review inspect.

## Dispatch Parameters
- mode: multi
- tier: frontier

## Input

Same repo-relative paths as `inspect-synthesis`:

- `{review_brief_path}` — required; provider reads `review-brief.md`. No paraphrase as substitute.
- `{change_evidence_path}` — `review-change-evidence.md` when Gate A2 ran; diff/patch fidelity. Same path synthesis uses.
- Diff/file list — supplementary only; never replace `{change_evidence_path}` when that file exists.
- Severity buckets, noise rules

Absent/missing change-evidence file → header must include  
`[COVERAGE_GAP: change evidence file not provided — external review limited to review brief + file list]`

## Instructions

Assemble in order:

1. Authoritative paths — `{review_brief_path}` + `{change_evidence_path}` (when present); instruct read-first; shared plane with verifier, inspector, synthesis.
2. Supplementary — path-only diff list only if not redundant with evidence files.
3. Severity buckets + evidence requirements
4. Noise filtering
5. Instruction: adversarial review; blocking = E2+; tag claims; verify assumptions (exercise, not just confirm).

Prompt must require output shape: findings `[B]`/`[S]`/`[F]`, correctness, evidence table.

## Constraints

- Reference by repo-relative path; no full-file inline (CLI reads files).
- Task self-contained — no hidden session state.
- Skip notice = `[COVERAGE_GAP: envoy — skipped]` (reason in envoy file body if needed)
- `mode` / `tier` → `--mode` / `--tier` on `run.sh`
