#!/bin/sh
# inject-agents-md.sh
# SessionStart hook: inject project-level AGENTS.md files as context.
# Claude Code natively loads CLAUDE.md but not AGENTS.md. This hook bridges
# the gap so project-level AGENTS.md files are also visible in sessions.

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Find AGENTS.md files in project (fd preferred, find fallback)
if command -v fd >/dev/null 2>&1; then
  file_list=$(fd --type f --glob 'AGENTS.md' "$project_dir" 2>/dev/null | sort)
else
  file_list=$(find "$project_dir" \
    -name "AGENTS.md" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/vendor/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -type f 2>/dev/null | sort)
fi

found=0
echo "$file_list" | while IFS= read -r file; do
  [ -z "$file" ] && continue
  if [ "$found" -eq 0 ]; then
    echo "# Project AGENTS.md"
    echo ""
  fi
  echo "<!-- source: $file -->"
  cat "$file"
  echo ""
  found=$((found + 1))
done
