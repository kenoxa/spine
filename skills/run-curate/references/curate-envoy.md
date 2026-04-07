# Curate: Envoy

CLI dispatcher — assemble external-provider prompt for coverage gap discovery; never self-answer. Coverage gap discovery phase.

## Dispatch Parameters
- mode: multi
- tier: frontier

## Input

Dispatch prompt provides:
- `{knowledge_index_path}` — repo-relative path to `AGENTS.md`; provider reads `## Project Knowledge` section. No inline paraphrase as substitute.
- `{existing_entries}` — list of current knowledge file paths with one-line glosses (path + gloss only; no file body inline).
- `{project_context}` — brief project description extracted from `AGENTS.md` header; supplementary framing for the external provider.
- `{output_path}` — routing metadata for `run.sh` output.

Absent/missing knowledge index → assembled prompt must include  
`[COVERAGE_GAP: knowledge index not provided — coverage assessment limited to existing_entries list]`

## Instructions

Assemble prompt content in this order:

1. **Authoritative source** — `{knowledge_index_path}` (required); instruct provider to read `## Project Knowledge` as the shared index for this assessment, consistent with curator and synthesizer.
2. **Existing entries** — path + gloss list; no file bodies inline.
3. **Project context** — `{project_context}` when it adds framing beyond the index.
4. **Instruction**: "Given this project's skills, agents, hooks, and docs — what knowledge domains are unrepresented or under-covered? Surface gaps (absent domains) and watches (partial or potentially stale coverage). Cap total items at 3–5."

Output format requirement — instruct the provider to produce exactly these 5 sections:
1. **Coverage assessment summary** — overall state of knowledge coverage; one paragraph.
2. **GAP items** — missing domains; each item: domain name, rationale, suggested file name.
3. **WATCH items** — partial or potentially stale coverage; same shape as GAP items.
4. **Rationale** — per-item justification referenced to project context or index entries.
5. **Confidence** — self-assessed confidence per item (high / medium / low).

Phase 4 Present consumes GAP and WATCH items; Rationale and Confidence are supplementary context.

## Constraints

- Repo-relative paths only; no file-body inline.
- Self-contained prompt — no session-internal refs.
- Cap: 3–5 total items across GAP + WATCH combined.
- Findings are advisory only (E1) — cannot cross E2+ promotion gate. Curator retains sole promote/update/prune authority.
- Skip notice = `[COVERAGE_GAP: envoy — skipped]`
- Use `mode` and `tier` from `## Dispatch Parameters` as `--mode` and `--tier` flags on `run.sh` invocation.
