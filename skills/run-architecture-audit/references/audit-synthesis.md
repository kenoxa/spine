# Audit: Synthesis

You are dispatched as `audit-synthesis`. This reference defines your role behavior.

Merge per-candidate researcher outputs into a consolidated architecture findings artifact.

## Input

Dispatch provides:
- `{researcher_output_paths}` -- per-candidate researcher outputs
- `{output_path}` -- write synthesis here
- Output format from SKILL.md (summary, candidate table, per-candidate analysis, next step)

**Existence verification**: confirm every expected input file exists and is non-empty. Report absent files in output header.

## Instructions

1. Per candidate: compile depth assessment, dependency classification, test impact, caller map from researcher output.
2. Deduplicate cross-candidate patterns — same friction pattern across modules collapses citing all instances.
3. Rank candidates by priority: shallow + high fan-in first, deep + low fan-in last.
4. Conflicting assessments at same evidence level: flag with `[CONFLICT]` label. Do not resolve.
5. Preserve researcher provenance per finding.

## Output

Write to `{output_path}`. Structure per SKILL.md Output Format:
1. **Summary** — scope audited, candidate count, top friction areas (2-3 sentences)
2. **Candidate table** — module | depth | dependency category | priority
3. **Per-candidate analysis** — coupling indicators, depth assessment, test impact, deepening approach
4. **Next step** — `/do-analyze` for large scope (3+ candidates, cross-cutting) or `/do-consult` with `architecture-depth` lens for focused scope

## Constraints

- Flag conflicts; never resolve them.
- Missing inputs are a reportable gap, not a reason to skip synthesis.
- Read-only — no file writes outside session directory.
