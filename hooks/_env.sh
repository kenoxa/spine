#!/bin/sh
# _env.sh — POSIX sh environment bootstrap for Spine hooks.
# Fixes restricted PATH in hook runner environments (Claude Code, Codex, Cursor, OpenCode).
#
# Usage as shebang:  #!/path/to/_env.sh   (install.sh rewrites shebangs at install time)
# Usage as wrapper:  _env.sh <hook-name>  (bare name → resolved in hooks dir)
# Usage as source:   . _env.sh
#
# spine:managed — do not edit

# Detect source vs direct execution (positional args leak when sourced)
_spine_env_exec=false
case "$0" in
  *_env.sh) _spine_env_exec=true ;;
esac

# Idempotency guard
if [ -n "$SPINE_ENV_LOADED" ]; then
  $_spine_env_exec && [ $# -gt 0 ] && exec "$@"
  return 0 2>/dev/null || exit 0
fi
export SPINE_ENV_LOADED=1

# Source user environment (POSIX-safe — .zshenv must use [ ] not [[ ]])
[ -f "$HOME/.zshenv" ] && . "$HOME/.zshenv" || true

# Source Spine configuration
[ -f "$HOME/.config/spine/.env" ] && . "$HOME/.config/spine/.env" || true

# Prepend known tool paths (skip already-present entries)
for _spine_p in \
  "$HOME/.cargo/bin" \
  "/home/linuxbrew/.linuxbrew/bin" \
  "/usr/local/bin" \
  "/opt/homebrew/bin" \
  "$HOME/.local/bin" \
  "$HOME/.bun/bin"; do
  case ":$PATH:" in
    *":$_spine_p:"*) ;;
    *) [ -d "$_spine_p" ] && PATH="$_spine_p:$PATH" ;;
  esac
done
unset _spine_p
export PATH

# Export hooks directory for hook scripts
export SPINE_HOOKS_DIR="${SPINE_HOOKS_DIR:-$HOME/.config/spine/hooks}"

# Diagnostic mode: verify tool access
if [ "${SPINE_ENV_VERIFY:-}" = "1" ]; then
  for _spine_t in bun node probe jq fd rg; do
    if command -v "$_spine_t" >/dev/null 2>&1; then
      printf 'spine-env: %s → %s\n' "$_spine_t" "$(command -v "$_spine_t")" >&2
    else
      printf 'spine-env: %s → NOT FOUND\n' "$_spine_t" >&2
    fi
  done
  unset _spine_t
fi

# Wrapper / shebang mode: exec the given command (only when directly executed)
# When used as shebang (#!/path/to/_env.sh), kernel passes the script as $1.
# Run .sh scripts via /bin/sh to avoid shebang re-entry loop.
if $_spine_env_exec && [ $# -gt 0 ]; then
  unset _spine_env_exec
  # Resolve bare hook filenames (*.sh, *.ts) relative to hooks directory.
  # Other commands (absolute paths, binaries) pass through as-is.
  case "$1" in
    *.sh)
      case "$1" in
        /*|./*) _spine_cmd="$1" ;;
        *)      _spine_cmd="$SPINE_HOOKS_DIR/$1" ;;
      esac
      shift
      exec /bin/sh "$_spine_cmd" "$@"  # /bin/sh avoids shebang re-entry loop
      ;;
    *.ts)
      case "$1" in
        /*|./*) _spine_cmd="$1" ;;
        *)      _spine_cmd="$SPINE_HOOKS_DIR/$1" ;;
      esac
      shift
      exec "$_spine_cmd" "$@"
      ;;
    *)
      exec "$@"
      ;;
  esac
fi
unset _spine_env_exec
