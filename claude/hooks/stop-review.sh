#!/bin/bash
# stop-review.sh
# Claude Code Stop hook: async advisory review of uncommitted changes on session exit.
# Triggered by Stop event via hooks.json (no matcher — fires on all exits).
# Dispatches a backgrounded envoy review so session exit is never blocked.
#
# Exit codes: always 0 (ALLOW — never block session exit).

# --- Opt-in gate ---
if [ "${SPINE_STOP_REVIEW}" != "advisory" ]; then
  exit 0
fi

# --- Required tools ---
if ! command -v git &>/dev/null; then
  exit 0
fi

# --- Dirty check ---
dirty=$(git status --porcelain 2>/dev/null)
if [ -z "$dirty" ]; then
  exit 0
fi

# --- Setup ---
review_dir=".scratch/stop-review"
mkdir -p "$review_dir"
ts=$(date +%Y%m%d-%H%M%S)
prompt_file="$review_dir/review-$ts.prompt"
output_file="$review_dir/review-$ts.md"
log_file="$review_dir/review-$ts.log"

# --- Build prompt ---
{
  cat <<'HEADER'
Quick review of uncommitted changes in this session.

Role: independent advisor. Answer this consultation directly in the format below.
Do not ask clarifying questions. Tag all claims with evidence levels (E0-E3).

## Output Format

### Findings

Group by severity: CRITICAL > HIGH > MEDIUM > LOW > NOTE.
Each finding: severity, file, description, evidence level tag.

---

HEADER

  echo '## git status'
  echo '```'
  echo "$dirty"
  echo '```'
  echo

  # Staged changes (if any)
  staged=$(git diff --cached 2>/dev/null | head -500)
  if [ -n "$staged" ]; then
    echo '## Staged changes (git diff --cached)'
    echo '```diff'
    echo "$staged"
    echo '```'
    echo
  fi

  # Unstaged changes
  unstaged=$(git diff 2>/dev/null | head -500)
  if [ -n "$unstaged" ]; then
    echo '## Unstaged changes (git diff)'
    echo '```diff'
    echo "$unstaged"
    echo '```'
    echo
  fi

  # Prompt footer (best-effort append)
  footer="$HOME/.agents/skills/use-envoy/references/prompt-footer.md"
  if [ -f "$footer" ]; then
    echo '---'
    cat "$footer"
  fi
} > "$prompt_file"

# --- Dispatch (backgrounded) ---
run_sh="$HOME/.agents/skills/use-envoy/scripts/run.sh"
if [ ! -f "$run_sh" ]; then
  exit 0
fi

sh "$run_sh" \
  --hint claude --tier fast --mode single \
  --prompt-file "$prompt_file" --output-file "$output_file" \
  --stderr-log "$log_file" &
disown

exit 0
