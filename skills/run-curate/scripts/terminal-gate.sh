#!/bin/sh
# terminal-gate.sh — Deterministic skeleton for /run-curate --terminal mode.
#
# Usage: sh terminal-gate.sh <session-dir>
#
# Reads the session's session-log.md, frame-artifact.md, design-artifact.md,
# and any build-status.json candidate file, then writes a structured
# `curate-report.md` to `<session-dir>/curate-report.md`. The report contains:
#
#   - Session header (id, branch, generated-at)
#   - Inventory of source artifacts (presence/absence)
#   - Slot for AI-synthesized learnings (mainthread fills in if it has budget)
#   - Knowledge-candidate scaffolding (NOT promoted — user-gated apply)
#
# This is the MECHANICAL portion of the terminal gate. Mainthread may augment
# with AI synthesis afterward, subject to the 60s timeout in
# spec §5.3 — but the baseline report is always present, so `build-status.json`
# can reference it unconditionally.
#
# Read-only on every input. Writes exactly one file: curate-report.md.

set -eu

[ $# -ge 1 ] || {
    printf 'usage: sh terminal-gate.sh <session-dir>\n' >&2
    exit 2
}

dir="$1"
[ -d "$dir" ] || {
    printf 'terminal-gate: session dir not found: %s\n' "$dir" >&2
    exit 1
}

sid="${dir##*/}"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')

report="$dir/curate-report.md"

# Inventory helper — prints "presence: path" line
inv() {
    label="$1"; path="$2"
    if [ -f "$path" ]; then
        printf -- '- **%s**: `%s` (present, %d bytes)\n' "$label" "$path" "$(wc -c <"$path" | tr -d ' ')"
    else
        printf -- '- **%s**: `%s` (MISSING)\n' "$label" "$path"
    fi
}

# Extract decisions from session-log Phase Trace (rows in the markdown table).
decisions_section() {
    log="$dir/session-log.md"
    if [ ! -f "$log" ]; then
        printf '_(session-log.md not present — no decisions extracted.)_\n'
        return
    fi
    # Grab table rows with | Phase | Mode | Decision | Notes |-style columns,
    # skip headers (separator lines or "Phase | Mode" header).
    awk -F'|' '
        /^\| *Phase *\| *Mode *\| *Decision *\| *Notes *\|/ {next}
        /^\|[ -]+\|[ -]+\|[ -]+\|[ -]+\|$/ {next}
        /^\|/ {
            # at least 5 |-delimited fields means a table row
            if (NF >= 5) {
                phase=$2; mode=$3; decision=$4
                gsub(/^ +| +$/, "", phase)
                gsub(/^ +| +$/, "", mode)
                gsub(/^ +| +$/, "", decision)
                if (phase != "" && decision != "") {
                    printf "- **%s** (%s) — %s\n", phase, mode, decision
                }
            }
        }
    ' "$log"
}

# Look for knowledge_candidate markers in session-log and artifacts.
knowledge_candidates() {
    found=0
    for f in "$dir/session-log.md" "$dir/frame-artifact.md" "$dir/design-artifact.md"; do
        [ -f "$f" ] || continue
        if grep -l 'knowledge_candidate' "$f" >/dev/null 2>&1; then
            found=$((found + 1))
            printf -- '- found in `%s`:\n' "$f"
            grep -n 'knowledge_candidate' "$f" | head -5 | sed 's/^/  - /'
        fi
    done
    if [ "$found" = "0" ]; then
        printf '_(no `knowledge_candidate` markers found across session artifacts.)_\n'
    fi
}

{
    printf '# Curate Report — `%s`\n\n' "$sid"
    printf '_Generated: %s · branch: %s · mode: terminal-gate_\n\n' "$ts" "$branch"

    printf '## Source artifacts\n\n'
    inv "Session log" "$dir/session-log.md"
    inv "Frame artifact" "$dir/frame-artifact.md"
    inv "Design artifact" "$dir/design-artifact.md"
    inv "Build status (candidate)" "$dir/build-status.json"
    inv "Events stream" "$dir/events.jsonl"
    printf '\n'

    printf '## Decisions captured\n\n'
    decisions_section
    printf '\n'

    printf '## Knowledge candidates (NOT promoted — user-gated)\n\n'
    printf '_The terminal gate never auto-promotes to `docs/`. Run `/run-curate` standalone to review and apply._\n\n'
    knowledge_candidates
    printf '\n'

    printf '## Mainthread synthesis slot\n\n'
    printf '_If mainthread has remaining budget (<60s per spec §5.3), it may append a synthesized learnings section below. Otherwise this slot remains empty and `build-status.json` records `curate_status: "skeleton-only"`._\n'
} > "$report"

printf '%s\n' "$report"
