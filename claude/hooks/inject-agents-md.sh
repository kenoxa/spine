#!/bin/bash
# inject-agents-md.sh
# Claude Code SessionStart hook: inject project-level AGENTS.md files as context.
#
# Claude Code natively loads CLAUDE.md but not AGENTS.md. This hook bridges
# the gap so project-level AGENTS.md files (used by Cursor and Codex natively)
# are also visible in Claude Code sessions.
#
# Install in ~/.claude/settings.json:
#   {
#     "hooks": {
#       "SessionStart": [{
#         "hooks": [{ "type": "command", "command": "path/to/inject-agents-md.sh" }]
#       }]
#     }
#   }

set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Find AGENTS.md files in project (fd preferred, find fallback)
if command -v fd &>/dev/null; then
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
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if [ "$found" -eq 0 ]; then
    echo "# Project AGENTS.md"
    echo ""
  fi
  echo "<!-- source: $file -->"
  cat "$file"
  echo ""
  found=$((found + 1))
done <<< "$file_list"
