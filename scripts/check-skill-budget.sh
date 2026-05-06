#!/usr/bin/env bash
# Verify Σ(desc_len + 109) across all active skills stays under threshold.
# Usage: scripts/check-skill-budget.sh [repo-root]
# Exit 0 = within budget. Exit 1 = exceeded. Exit 2 = missing dependency.
set -euo pipefail

OVERHEAD=109
THRESHOLD=7700  # actual Claude Code budget is 8000c; threshold gives ~200c headroom for new skills
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

if ! command -v yq &>/dev/null; then
  echo "ERROR: yq required (brew install yq)" >&2
  exit 2
fi

total=0
count=0
declare -a offenders=()

# Local skills
for md in "$ROOT/skills/"*/SKILL.md; do
  [[ -f "$md" ]] || continue
  desc=$(yq --front-matter=extract e '.description' "$md" 2>/dev/null) || continue
  [[ -z "$desc" || "$desc" == "null" ]] && continue
  len=${#desc}
  total=$((total + len + OVERHEAD))
  count=$((count + 1))
  [[ $len -gt 90 ]] && offenders+=("${len}c  $(basename "$(dirname "$md")")")
done

# Global overrides
overrides="$ROOT/skill-overrides.yaml"
if [[ -f "$overrides" ]]; then
  while IFS= read -r desc; do
    [[ -z "$desc" || "$desc" == "null" ]] && continue
    len=${#desc}
    total=$((total + len + OVERHEAD))
    count=$((count + 1))
    [[ $len -gt 90 ]] && offenders+=("${len}c  [global override]")
  done < <(yq e '.skills[].description' "$overrides" 2>/dev/null)
fi

remaining=$((THRESHOLD - total))
echo "Skills: $count  |  Budget used: ${total}c / ${THRESHOLD}c  |  Remaining: ${remaining}c"

if [[ $total -gt $THRESHOLD ]]; then
  echo "FAIL: budget exceeded by $((total - THRESHOLD))c" >&2
  if [[ ${#offenders[@]} -gt 0 ]]; then
    echo "Long descriptions (>90c):" >&2
    printf '  %s\n' "${offenders[@]}" | sort -rn | head -5 >&2
  fi
  exit 1
fi
