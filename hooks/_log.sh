#!/bin/sh
# _log.sh — POSIX sh shared log helper for Spine hooks.
# Source: . "$(dirname "$0")/_log.sh"
# spine:managed — do not edit

_spine_log() {
  # _spine_log <event> <hook> <tool>
  # Toggle guard: skip if SPINE_HOOK_LOG is unset or empty
  [ -n "${SPINE_HOOK_LOG:-}" ] || return 0

  # jq availability guard: skip logging silently if jq is absent
  command -v jq >/dev/null 2>&1 || return 0

  _spine_log_file="${SPINE_LOG_FILE:-$HOME/.config/spine/logs/hooks.jsonl}"

  # Defensive mkdir: covers manual SPINE_HOOK_LOG=1 before install runs
  mkdir -p "$(dirname "$_spine_log_file")" 2>/dev/null || true

  # Build JSONL entry
  _spine_log_entry=$(jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg event "$1" \
    --arg hook "$2" \
    --arg tool "$3" \
    '{ts:$ts,event:$event,hook:$hook,tool:$tool}' 2>/dev/null) || {
    unset _spine_log_size _spine_log_entry _spine_log_file
    return 0
  }

  # Rotation: check size, rotate at 500 KB
  _spine_log_size=$( (wc -c < "$_spine_log_file") 2>/dev/null || echo 0)
  if [ "$_spine_log_size" -ge 512000 ] 2>/dev/null; then  # keep in sync with spineLog() in inject-types-on-read.ts
    rm -f "${_spine_log_file}.2" 2>/dev/null || true
    mv -f "${_spine_log_file}.1" "${_spine_log_file}.2" 2>/dev/null || true
    mv -f "$_spine_log_file" "${_spine_log_file}.1" 2>/dev/null || true
  fi

  # Append entry
  printf '%s\n' "$_spine_log_entry" >> "$_spine_log_file" 2>/dev/null || true

  unset _spine_log_size _spine_log_entry _spine_log_file
}
