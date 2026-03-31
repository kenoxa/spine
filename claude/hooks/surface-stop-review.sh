#!/bin/bash
# surface-stop-review.sh
# Claude Code SessionStart hook: remind user about unread stop-review findings.
# Checks .scratch/stop-review/ for *.md files from a previous session's exit review.
# Surfaces a systemMessage listing them, then renames to *.surfaced.md to avoid repeat.
#
# Exit codes: always 0. Output: JSON with optional systemMessage.

# Guarantee valid JSON on any failure
trap 'echo "{}"; exit 0' ERR

review_dir=".scratch/stop-review"

# No directory or no .md files → nothing to surface
if [ ! -d "$review_dir" ]; then
  echo '{}'
  exit 0
fi

# Collect unread findings (*.md but not *.surfaced.md, *.prompt, *.log)
findings=()
for f in "$review_dir"/*.md; do
  [ -f "$f" ] || continue
  case "$f" in
    *.surfaced.md|*.prompt|*.log) continue ;;
  esac
  findings+=("$f")
done

if [ ${#findings[@]} -eq 0 ]; then
  echo '{}'
  exit 0
fi

# Build reminder message
msg="A previous session's stop-review left findings you haven't seen yet:"
for f in "${findings[@]}"; do
  msg+=$'\n'"  - $(basename "$f")"
done
msg+=$'\n'"Review with: cat ${review_dir}/<filename>"

# Surface via systemMessage
if command -v jq &>/dev/null; then
  jq -n --arg msg "$msg" '{ "systemMessage": $msg }'
else
  # Manual JSON escape fallback
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | sed ':a;N;$!ba;s/\n/\\n/g')
  printf '{"systemMessage":"%s"}\n' "$escaped"
fi

# Mark as surfaced so we don't remind again
for f in "${findings[@]}"; do
  mv "$f" "${f%.md}.surfaced.md" 2>/dev/null || true
done

exit 0
