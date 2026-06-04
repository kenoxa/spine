#!/usr/bin/env bash
# Lint: No run-* Cycles
# Detects cross-run-* references that violate the SPINE.md invariant.
# Contract documented in: lint-no-run-cycles.md
#
# Strips the dir prefix before self-filtering so the exclusion matches content, not file path.
set -eu
repo_root="$(git rev-parse --show-toplevel)"
violations=0
for dir in "$repo_root"/skills/run-*/; do
  self="$(basename "$dir")"
  # shellcheck disable=SC2016  # literal install-path patterns, not shell expansions
  results=$(grep -rn \
    -e "/run-[a-z][a-z-]*" \
    -e "skills/run-[a-z][a-z-]*/" \
    "$dir" --include="*.md" 2>/dev/null \
    | sed "s|${dir}||" \
    | grep -v "run-\*" \
    | grep -v "/${self}[^a-z-]" \
    | grep -v "/${self}$" \
    | grep -v '\$HOME.*skills/run-' \
    | grep -v 'SPINE_SKILLS_DIR.*run-' \
    | grep -v '\.agents/skills/run-' \
    ) || true
  if [ -n "$results" ]; then
    echo "--- $self ---"
    echo "$results"
    violations=$((violations + 1))
  fi
done
if [ "$violations" -gt 0 ]; then
  echo ""
  echo "FAIL: $violations run-* dir(s) with cross-run-* references"
  exit 1
fi
echo "PASS: 0 cross-run-* violations"
