#!/usr/bin/env bash
# Spine installer — cross-platform AI coding setup for Cursor, Claude Code, and Codex.
# https://github.com/kenoxa/spine
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh | bash
#
# Or inspect first:
#   curl -fsSL https://raw.githubusercontent.com/kenoxa/spine/main/install.sh -o install.sh
#   less install.sh
#   bash install.sh

set -euo pipefail

REPO="kenoxa/spine"
BRANCH="main"
GLOBAL_SKILLS=(
  "obra/superpowers -s brainstorming"
  "nicobailon/visual-explainer -s visual-explainer"
  "jeffallan/claude-skills -s security-reviewer"
  "anthropics/claude-code -s frontend-design"
  "wshobson/agents -s wcag-audit-patterns"
  "softaworks/agent-toolkit -s reducing-entropy"
  "sickn33/antigravity-awesome-skills -s typescript-expert"
)

# --- Helpers ---

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn()  { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }
done_msg() { printf '\033[1;32m✓\033[0m %s\n' "$*" >&2; }

# --- Download source into temp dir ---

download_source() {
  local tmpdir
  tmpdir=$(mktemp -d)

  if command -v git &>/dev/null && git clone --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$tmpdir/spine" 2>/dev/null; then
    info "Cloned $REPO"
    echo "$tmpdir/spine"
  elif command -v curl &>/dev/null && command -v tar &>/dev/null; then
    info "Downloading $REPO archive..."
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$tmpdir"
    echo "$tmpdir/spine-$BRANCH"
  else
    error "Neither git nor curl+tar found. Install one of them and retry."
    rm -rf "$tmpdir"
    return 1
  fi
}

# --- Detect installed tools ---

detect_tools() {
  local tools=()
  [ -d "$HOME/.cursor" ] && tools+=("cursor")
  [ -d "$HOME/.claude" ] && tools+=("claude")
  [ -d "$HOME/.codex" ]  && tools+=("codex")

  # Default to Claude Code if nothing detected
  if [ ${#tools[@]} -eq 0 ]; then
    tools=("claude")
  fi

  echo "${tools[@]}"
}

# --- Install files for a single tool ---

install_tool() {
  local tool="$1" src="$2"
  local target="$HOME/.$tool"

  info "Installing to $target/..."

  # Guardrails: CLAUDE.md for Claude Code, AGENTS.md for others
  if [ "$tool" = "claude" ]; then
    backup_if_exists "$target/CLAUDE.md"
    cp "$src/AGENTS.global.md" "$target/CLAUDE.md"
  else
    backup_if_exists "$target/AGENTS.md"
    cp "$src/AGENTS.global.md" "$target/AGENTS.md"
  fi

  # Agents
  mkdir -p "$target/agents"
  cp -r "$src/agents/"* "$target/agents/"

  done_msg "$tool: guardrails, agents"

  # Claude Code extras: hook + settings.json
  if [ "$tool" = "claude" ]; then
    install_claude_hook "$src" "$target"
  fi
}

# --- Claude Code hook + settings.json ---

install_claude_hook() {
  local src="$1" target="$2"

  # Copy hook script
  mkdir -p "$target/hooks"
  cp "$src/hooks/inject-agents-md.sh" "$target/hooks/"
  chmod +x "$target/hooks/inject-agents-md.sh"

  done_msg "claude: SessionStart hook"

  # Patch settings.json
  patch_settings_json "$target"
}

patch_settings_json() {
  local target="$1"
  local settings="$target/settings.json"
  local hook_cmd="$target/hooks/inject-agents-md.sh"

  if ! command -v jq &>/dev/null; then
    warn "jq not found — cannot auto-patch settings.json"
    echo ""
    echo "  Add this to $settings manually:"
    echo ""
    echo '  {'
    echo '    "hooks": {'
    echo '      "SessionStart": [{'
    echo '        "hooks": [{ "type": "command", "command": "'"$hook_cmd"'" }]'
    echo '      }]'
    echo '    }'
    echo '  }'
    echo ""
    return 0
  fi

  # Create settings.json if missing
  if [ ! -f "$settings" ]; then
    echo '{}' > "$settings"
  fi

  # Check if hook is already registered (idempotent)
  if jq -e ".hooks.SessionStart[]?.hooks[]? | select(.command == \"$hook_cmd\")" "$settings" &>/dev/null; then
    done_msg "claude: settings.json already has SessionStart hook"
    return 0
  fi

  # Backup
  backup_if_exists "$settings"

  # Merge hook config, preserving existing settings
  local tmp
  tmp=$(mktemp)
  jq --arg cmd "$hook_cmd" '
    .hooks //= {} |
    .hooks.SessionStart //= [] |
    .hooks.SessionStart += [{"hooks": [{"type": "command", "command": $cmd}]}]
  ' "$settings" > "$tmp"

  # Validate JSON before replacing
  if jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
    done_msg "claude: settings.json patched with SessionStart hook"
  else
    error "Generated invalid JSON — settings.json left unchanged"
    rm -f "$tmp"
    return 1
  fi
}

# --- Backup helper ---

backup_if_exists() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak"
  fi
}

# --- Install skills via npx ---

install_skills() {
  if ! command -v npx &>/dev/null; then
    warn "npx not found — cannot install skills automatically"
    echo ""
    echo "  Install skills manually:"
    echo "    npx skills add $REPO -s '*' -a '*' -g -y"
    for entry in "${GLOBAL_SKILLS[@]}"; do
      echo "    npx skills add $entry -a '*' -g -y"
    done
    echo ""
    return 0
  fi

  # Spine skills (all at once)
  info "Installing spine skills..."
  if npx skills add "$REPO" -s '*' -a '*' -g -y 2>/dev/null; then
    done_msg "spine: all skills"
  else
    warn "Failed to install spine skills"
    echo "    npx skills add $REPO -s '*' -a '*' -g -y" >&2
  fi

  # Global/external skills
  info "Installing global skills..."
  local failed=()
  for entry in "${GLOBAL_SKILLS[@]}"; do
    # entry is e.g. "obra/superpowers -s brainstorming"
    local skill_name="${entry##*-s }"
    if npx skills add $entry -a '*' -g -y 2>/dev/null; then
      done_msg "global: $skill_name"
    else
      failed+=("$entry")
      warn "Failed to install global skill: $skill_name"
    fi
  done

  if [ ${#failed[@]} -gt 0 ]; then
    warn "Some global skills failed. Install manually:"
    for entry in "${failed[@]}"; do
      echo "    npx skills add $entry -a '*' -g -y" >&2
    done
  fi
  echo ""
}

# --- Main ---

main() {
  echo ""
  info "Spine installer — cross-platform AI coding setup"
  echo ""

  # Download (or use SPINE_LOCAL_SRC for testing)
  local src
  if [ -n "${SPINE_LOCAL_SRC:-}" ]; then
    src="$SPINE_LOCAL_SRC"
    info "Using local source: $src"
  else
    src=$(download_source)
    trap 'rm -rf "$(dirname "$src")"' EXIT
  fi

  # Detect tools
  local tools
  read -ra tools <<< "$(detect_tools)"

  info "Detected tools: ${tools[*]}"
  echo ""

  # Install guardrails, agents, and hooks per tool
  for tool in "${tools[@]}"; do
    install_tool "$tool" "$src"
    echo ""
  done

  # Install skills via npx skills
  install_skills

  # Summary
  echo "---"
  done_msg "Spine installed for: ${tools[*]}"
  echo ""
}

main "$@"
