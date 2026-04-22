#!/bin/sh
# inject-agents-md.sh
# SessionStart hook: inject project-level AGENTS.md files as context.
# Claude Code natively loads CLAUDE.md but not AGENTS.md. This hook walks up
# from the session's cwd to the git root, emitting every AGENTS.md on the path.

trap 'exit 0' HUP INT TERM

# shellcheck source=./_log.sh
. "$(dirname "$0")/_log.sh"
_spine_log sessionStart inject-agents-md ''

# Bail silently when running under Cursor — this is a Claude-only hook.
# Cursor parses sessionStart hook stdout as JSON; plain text causes SyntaxError.
[ "${SPINE_PROVIDER_IS_CURSOR:-}" = "1" ] && { printf '{}'; exit 0; }

# --- Anchor resolution ---
# Prefer stdin `cwd` (Claude Code hook payload) → CLAUDE_PROJECT_DIR → pwd.
input=$(cat)

anchor=""
if command -v jq >/dev/null 2>&1 && [ -n "$input" ]; then
  anchor=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
fi
if [ -z "$anchor" ] || [ ! -d "$anchor" ]; then
  anchor="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi

# --- Walk-up discovery ---
# Collect AGENTS.md at every level from anchor to git root (inclusive).
# Stop at .git sentinel, $HOME ceiling, or filesystem root.
dir="$anchor"
files=""
# $HOME ceiling: don't slurp ~/AGENTS.md when no .git ancestor found under $HOME
while [ "$dir" != "/" ] && [ "$dir" != "$HOME" ]; do
  if [ -f "$dir/AGENTS.md" ]; then
    # Prepend so the final list is root-first after the walk completes
    files="$dir/AGENTS.md
$files"
  fi
  if [ -d "$dir/.git" ]; then
    break
  fi
  dir=$(dirname "$dir")
done

[ -z "$files" ] && exit 0

# --- Emit ---
printf '# Project AGENTS.md\n\n'
printf '%s\n' "$files" | while IFS= read -r file; do
  [ -z "$file" ] && continue
  printf '<!-- source: %s -->\n' "$file"
  cat "$file"
  printf '\n'
done

exit 0
