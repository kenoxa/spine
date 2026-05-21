#!/usr/bin/env bash
# Verify Σ(desc_len + OVERHEAD) across all active skills stays under the threshold.
# Models Claude Code's skill-listing budget: controlled by the `skillListingBudgetFraction`
# setting (default 0.01 = 1% of context window; requires v2.1.105+) or the
# `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var (fixed char count). Each skill's combined
# description + when_to_use is capped at `maxSkillDescriptionChars` (default 1536 chars).
# On overflow, least-used skill descriptions collapse to bare names; `/doctor` reports
# the truncation count. Skill names are always included; OVERHEAD approximates the
# per-skill name + structural framing consumed beyond the description text.
# Usage: scripts/check-skill-budget.sh [repo-root]
# Exit 0 = within budget. Exit 1 = exceeded. Exit 2 = missing dependency.
set -euo pipefail

# Undocumented empirical estimate of per-skill name + structural framing overhead
# (chars consumed beyond the description text itself); 109 is not derivable from
# any official Claude Code doc — treat as an approximation, not a verified constant.
OVERHEAD=109
# Models a SLASH_COMMAND_TOOL_CHAR_BUDGET-style fixed budget of 8000c (≈ 1% of a
# ~200K-token context; 2000 tokens ≈ 8000 chars); smaller-context models get a
# proportionally smaller budget. 300c headroom reserved for new skills.
THRESHOLD=7700
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
