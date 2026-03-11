#!/usr/bin/env bash
# Spine installer — AI coding setup for Cursor, Claude Code, and Codex.
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

# --- Colors (https://no-color.org/) ---

_C_BLUE='\033[1;34m' _C_YELLOW='\033[1;33m'
_C_RED='\033[1;31m'  _C_GREEN='\033[1;32m'
_C_RESET='\033[0m'
# shellcheck disable=SC2034
[ -n "${NO_COLOR:-}" ] && _C_BLUE='' _C_YELLOW='' _C_RED='' _C_GREEN='' _C_RESET=''

REPO="kenoxa/spine"
BRANCH="main"
GLOBAL_SKILLS=(
  "obra/superpowers -s brainstorming"
  "nicobailon/visual-explainer -s visual-explainer"
  "jeffallan/claude-skills -s security-reviewer"
  "anthropics/claude-code -s frontend-design"
  "wshobson/agents -s wcag-audit-patterns"
  "softaworks/agent-toolkit -s reducing-entropy"
  "mcollina/skills -s typescript-magician"
)

# --- Helpers ---

info()     { printf "${_C_BLUE}==>${_C_RESET} %s\n" "$*" >&2; }
warn()     { printf "${_C_YELLOW}WARN:${_C_RESET} %s\n" "$*" >&2; }
error()    { printf "${_C_RED}ERROR:${_C_RESET} %s\n" "$*" >&2; }
done_msg() { printf "  ${_C_GREEN}✓${_C_RESET} %s\n" "$*" >&2; }

# Run a command silently; on failure show captured output then return 1.
quiet() { local out; out=$("$@" 2>&1) || { echo "$out" >&2; return 1; }; }

# Step progress: step "1/5" "Checking dependencies"
step() { printf "\n${_C_BLUE}[%s]${_C_RESET} %s\n" "$1" "$2" >&2; }

# --- Dependency detection ---

# Check if a tool binary is on PATH.
# Handles formula-to-binary name differences (e.g., ripgrep → rg).
dep_present() {
  case "$1" in
    ripgrep)   command -v rg        >/dev/null 2>&1 ;;
    ast-grep)  command -v ast-grep  >/dev/null 2>&1 || command -v sg >/dev/null 2>&1 ;;
    node)      command -v node      >/dev/null 2>&1 || command -v nodejs >/dev/null 2>&1 ;;
    coreutils) command -v gtimeout  >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1 ;;
    *)         command -v "$1"      >/dev/null 2>&1 ;;
  esac
}

has_brew() { command -v brew >/dev/null 2>&1; }

# Install a Homebrew formula if not already on PATH or installed via brew.
brew_install_if_missing() {
  local formula="$1"
  dep_present "$formula" && return 0
  brew list --formula "$formula" >/dev/null 2>&1 && return 0
  if quiet brew install "$formula" </dev/null; then
    done_msg "Installed $formula via Homebrew"
  else
    warn "Failed to install $formula via Homebrew"
    return 1
  fi
}

# Ensure system deps are available. Attempts brew install on macOS; prints hints otherwise.
ensure_system_deps() {
  local os missing=()
  os="$(uname -s)"

  # Deps spine uses — sync with README.md CLI tools table when changing these
  local -a required=(git jq node)
  local -a recommended=(ast-grep bun coreutils fd ripgrep shellcheck shfmt)

  local use_brew=false
  if has_brew; then
    use_brew=true
  elif [ "$os" = "Darwin" ]; then
    warn "Homebrew not found — install it from https://brew.sh"
  fi

  # Collect missing deps
  for dep in "${required[@]}" "${recommended[@]}"; do
    dep_present "$dep" || missing+=("$dep")
  done

  if [ ${#missing[@]} -eq 0 ]; then
    done_msg "All dependencies found"
    return 0
  fi

  if $use_brew; then
    info "Installing missing tools via Homebrew: ${missing[*]}..."
    for dep in "${missing[@]}"; do
      brew_install_if_missing "$dep" || true
    done
  else
    warn "Missing tools: ${missing[*]}"
    if [ "$os" = "Darwin" ]; then
      echo "  After installing Homebrew, run:" >&2
      echo "    brew install ${missing[*]}" >&2
    else
      echo "  Install via your package manager, e.g.:" >&2
      echo "    sudo apt install ${missing[*]}  # Debian/Ubuntu (fd→fd-find, node→nodejs, coreutils is preinstalled)" >&2
      echo "    sudo dnf install ${missing[*]}  # Fedora/RHEL" >&2
    fi
    echo "" >&2
  fi
}

# --- Download source into temp dir ---

download_source() {
  local tmpdir
  tmpdir=$(mktemp -d)

  if command -v git &>/dev/null && quiet git clone --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$tmpdir/spine"; then
    echo "$tmpdir/spine"
  elif command -v curl &>/dev/null && command -v tar &>/dev/null; then
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

  # Cursor: config dir is sufficient (no standalone CLI binary)
  [ -d "$HOME/.cursor" ] && tools+=("cursor")

  # Claude Code / Codex: require CLI binary on PATH
  for tool in claude codex; do
    if command -v "$tool" >/dev/null 2>&1; then
      tools+=("$tool")
    elif [ -d "$HOME/.$tool" ]; then
      warn "$tool: config directory exists but CLI not found on PATH — skipping"
    fi
  done

  if [ ${#tools[@]} -eq 0 ]; then
    warn "No AI coding tools found (cursor, claude, codex)"
    warn "Install at least one, then re-run this installer"
  fi

  echo "${tools[@]}"
}

# --- Central directory setup ---

setup_central_dir() {
  local src="$1"
  local spine_dir="$HOME/.config/spine"

  mkdir -p "$spine_dir/agents"

  # Copy guardrails
  backup_if_exists "$spine_dir/SPINE.md"
  cp "$src/SPINE.md" "$spine_dir/SPINE.md"

  # Copy agents
  for agent in "$src/agents/"*.md; do
    [ -f "$agent" ] || continue
    cp "$agent" "$spine_dir/agents/"
  done

  # Remove stale agents no longer in source
  for existing in "$spine_dir/agents/"*.md; do
    [ -f "$existing" ] || continue
    local name
    name=$(basename "$existing")
    if [ ! -f "$src/agents/$name" ]; then
      backup_if_exists "$existing"
      rm "$existing"
    fi
  done

  done_msg "central directory: ~/.config/spine/"
}

# --- Install files for a single tool ---

install_tool() {
  local tool="$1" src="$2"
  local target="$HOME/.$tool"
  local spine_dir="$HOME/.config/spine"
  local spine_ref='@~/.config/spine/SPINE.md'

  mkdir -p "$target"

  # Guardrails: write @reference to provider root file
  local root_file
  if [ "$tool" = "claude" ]; then
    root_file="$target/CLAUDE.md"
  else
    root_file="$target/AGENTS.md"
  fi

  if [ ! -f "$root_file" ]; then
    # Fresh install
    echo "$spine_ref" > "$root_file"
  elif head -1 "$root_file" | grep -q '^@.*SPINE\.md$'; then
    # Already managed — preserve user content below
    :
  elif diff -q "$root_file" "$spine_dir/SPINE.md" >/dev/null 2>&1 || \
       head -1 "$root_file" | grep -q '^# \(AGENTS\|SPINE\)\.md$'; then
    # Spine-managed content (current or pre-rename) — safe to replace entirely
    backup_if_exists "$root_file"
    echo "$spine_ref" > "$root_file"
  else
    # User has custom content — prepend @reference, keep existing content
    backup_if_exists "$root_file"
    local tmp
    tmp=$(mktemp)
    printf '%s\n\n' "$spine_ref" > "$tmp"
    cat "$root_file" >> "$tmp"
    mv "$tmp" "$root_file"
  fi

  # Agents: per-file symlinks to central directory
  mkdir -p "$target/agents"
  for agent in "$spine_dir/agents/"*.md; do
    [ -f "$agent" ] || continue
    local name
    name=$(basename "$agent")
    # Back up regular files (not symlinks) before replacing
    if [ -f "$target/agents/$name" ] && [ ! -L "$target/agents/$name" ]; then
      backup_if_exists "$target/agents/$name"
    fi
    ln -sf "../../.config/spine/agents/$name" "$target/agents/$name"
  done

  done_msg "$tool: guardrails, agents"

  # Claude Code extras: plugin (hooks + agent-teams skill)
  if [ "$tool" = "claude" ]; then
    install_claude_plugin "$src" "$target"
  fi
}

# --- Claude Code plugin (hooks + agent-teams skill) ---

install_claude_plugin() {
  local src="$1" target="$2"

  # Determine marketplace source: local path for persistent checkouts, GitHub for downloads.
  # Check _SPINE_CLEANUP_DIR to distinguish local checkouts from git-cloned temp dirs.
  local marketplace_src="kenoxa/spine"
  [ -z "${_SPINE_CLEANUP_DIR:-}" ] && [ -d "$src/.git" ] && marketplace_src="$src"

  # Attempt plugin installation
  if quiet claude plugin marketplace add "$marketplace_src" && \
     quiet claude plugin install spine@kenoxa; then
    done_msg "claude: plugin (hooks + agent-teams skill)"
    return 0
  fi

  # Fallback: manual hook installation from claude/hooks/
  warn "Could not install Claude plugin — installing hook manually"

  local settings="$target/settings.json"
  local hook_cmd="$target/hooks/inject-agents-md.sh"

  mkdir -p "$target/hooks"
  for script in "$src"/claude/hooks/*.sh; do
    [ -f "$script" ] || continue
    cp "$script" "$target/hooks/"
    chmod +x "$target/hooks/$(basename "$script")"
  done

  done_msg "claude: hook scripts (fallback)"

  # Patch settings.json with SessionStart hook
  if ! command -v jq &>/dev/null; then
    warn "jq not found — cannot auto-patch settings.json"
    echo "  Install jq and re-run, or patch $settings manually." >&2
    return 0
  fi

  [ -f "$settings" ] || echo '{}' > "$settings"

  # Already registered? Skip.
  if jq -e --arg cmd "$hook_cmd" \
    '.hooks.SessionStart[]?.hooks[]? | select(.command == $cmd)' \
    "$settings" &>/dev/null; then
    done_msg "claude: settings.json already has SessionStart hook"
    return 0
  fi

  backup_if_exists "$settings"

  local tmp
  tmp=$(mktemp)
  jq --arg cmd "$hook_cmd" '
    .hooks //= {} |
    .hooks.SessionStart //= [] |
    .hooks.SessionStart += [{"hooks": [{"type": "command", "command": $cmd}]}]
  ' "$settings" > "$tmp"

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
  if [ -e "$file" ] || [ -L "$file" ]; then
    cp -L "$file" "${file}.bak" 2>/dev/null || true
  fi
}

# --- Install skills via npx ---

install_skills() {
  local skills_src="$1"; shift
  local detected_tools=("$@")

  # Build -a flags from detected tools, mapping to npx skills agent names
  local agent_flags=()
  for tool in "${detected_tools[@]}"; do
    case "$tool" in
      claude) agent_flags+=(-a "claude-code") ;;
      *)      agent_flags+=(-a "$tool") ;;
    esac
  done

  if ! command -v npx &>/dev/null; then
    warn "npx not found — cannot install skills automatically"
    echo "" >&2
    echo "  Install skills manually:" >&2
    echo "    npx skills add $skills_src -s '*' ${agent_flags[*]} -g -y" >&2
    for entry in "${GLOBAL_SKILLS[@]}"; do
      echo "    npx skills add $entry ${agent_flags[*]} -g -y" >&2
    done
    echo "" >&2
    return 0
  fi

  # Spine skills: install all, then remove any renamed/deleted orphans
  if quiet npx --yes skills add "$skills_src" -s '*' "${agent_flags[@]}" -g -y; then
    done_msg "spine: all skills"
  else
    warn "Failed to install spine skills"
    echo "    npx skills add $skills_src -s '*' ${agent_flags[*]} -g -y" >&2
  fi

  # Clean up orphaned spine skills (handles renames)
  local lock_file="$HOME/.agents/.skill-lock.json"
  if [ -f "$lock_file" ] && command -v jq &>/dev/null; then
    local orphans=()
    while IFS= read -r skill; do
      [ -z "$skill" ] && continue
      if [ ! -d "$skills_src/skills/$skill" ]; then
        orphans+=("$skill")
      fi
    done < <(jq -r '.skills | to_entries[] | select(.value.source == "kenoxa/spine" or .value.source == "'"$skills_src"'") | .key' "$lock_file" 2>/dev/null)

    if [ ${#orphans[@]} -gt 0 ]; then
      quiet npx --yes skills remove "${orphans[@]}" "${agent_flags[@]}" -g -y || true
    fi
  fi

  # Global/external skills
  local failed=()
  for entry in "${GLOBAL_SKILLS[@]}"; do
    # entry is e.g. "obra/superpowers -s brainstorming"
    local skill_name="${entry##*-s }"
    if quiet npx --yes skills add $entry "${agent_flags[@]}" -g -y; then
      done_msg "global: $skill_name"
    else
      failed+=("$entry")
      warn "Failed to install global skill: $skill_name"
    fi
  done

  if [ ${#failed[@]} -gt 0 ]; then
    warn "Some global skills failed. Install manually:"
    for entry in "${failed[@]}"; do
      echo "    npx skills add $entry ${agent_flags[*]} -g -y" >&2
    done
  fi

  # Clean up global skills that Spine previously installed but no longer manages.
  # Add skill names here when swapping one global skill for another.
  local -a RETIRED_GLOBAL_SKILLS=(
    "typescript-expert"  # replaced by typescript-magician (mcollina/skills)
  )

  if [ ${#RETIRED_GLOBAL_SKILLS[@]} -gt 0 ] && [ -f "$lock_file" ] && command -v jq &>/dev/null; then
    local global_orphans=()
    for skill in "${RETIRED_GLOBAL_SKILLS[@]}"; do
      if jq -e --arg s "$skill" '.skills[$s]' "$lock_file" &>/dev/null; then
        global_orphans+=("$skill")
      fi
    done
    if [ ${#global_orphans[@]} -gt 0 ]; then
      info "Removing retired global skills: ${global_orphans[*]}"
      quiet npx --yes skills remove "${global_orphans[@]}" "${agent_flags[@]}" -g -y || true
    fi
  fi
}

# --- Clean up stale files across provider directories ---

cleanup_stale_files() {
  local detected_tools=("$@")
  local spine_targets=(".config/spine/" ".agents/skills/")
  local cleaned=0

  for tool in "${detected_tools[@]}"; do
    local target="$HOME/.$tool"
    for subdir in agents skills; do
      local dir="$target/$subdir"
      [ -d "$dir" ] || continue

      # Remove broken symlinks pointing into spine-managed paths
      for link in "$dir"/*; do
        [ -L "$link" ] || continue
        [ -e "$link" ] && continue
        local dest
        dest=$(readlink "$link")
        local is_spine=false
        for prefix in "${spine_targets[@]}"; do
          case "$dest" in *"$prefix"*) is_spine=true; break ;; esac
        done
        if $is_spine; then
          rm "$link"
          cleaned=$((cleaned + 1))
        fi
      done

      # Remove .bak files left by backup_if_exists
      for bak in "$dir"/*.bak; do
        [ -f "$bak" ] || continue
        rm "$bak"
        cleaned=$((cleaned + 1))
      done
    done
  done

  if [ "$cleaned" -gt 0 ]; then
    done_msg "Removed $cleaned stale file(s)"
  else
    done_msg "No stale files found"
  fi
}

# --- Main ---

main() {
  echo "" >&2
  info "Spine installer — AI coding setup"

  # Step 1: System dependencies
  step "1/7" "Checking system dependencies..."
  ensure_system_deps

  # Step 2: Resolve source
  step "2/7" "Resolving source..."
  local src script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" && pwd)"
  if [ -f "$script_dir/SPINE.md" ] && [ -d "$script_dir/skills" ]; then
    src="$script_dir"
    done_msg "Using local repo: $src"
  elif [ -n "${SPINE_LOCAL_SRC:-}" ]; then
    src="$SPINE_LOCAL_SRC"
    done_msg "Using local source: $src"
  else
    src=$(download_source)
    _SPINE_CLEANUP_DIR="$(dirname "$src")"
    trap 'rm -rf "$_SPINE_CLEANUP_DIR"' EXIT
    done_msg "Downloaded $REPO"
  fi

  # Step 3: Set up central directory
  step "3/7" "Setting up central directory..."
  setup_central_dir "$src"

  # Step 4: Detect tools
  step "4/7" "Detecting installed tools..."
  local tools
  read -ra tools <<< "$(detect_tools)"

  if [ ${#tools[@]} -eq 0 ] || [ -z "${tools[0]}" ]; then
    echo "" >&2
    error "Nothing to install — no supported tools detected"
    return 1
  fi

  done_msg "Found: ${tools[*]}"

  # Step 5: Install guardrails, agents, and plugin
  step "5/7" "Installing guardrails, agents, and plugin..."
  for tool in "${tools[@]}"; do
    install_tool "$tool" "$src"
  done

  # Step 6: Install skills
  step "6/7" "Installing skills..."
  install_skills "$src" "${tools[@]}"

  # Step 7: Clean up stale files
  step "7/7" "Cleaning up stale files..."
  cleanup_stale_files "${tools[@]}"

  # Summary
  echo "" >&2
  echo "---" >&2
  printf "${_C_GREEN}✓ Spine installed for: ${tools[*]}${_C_RESET}\n" >&2
  echo "" >&2
}

main "$@"
