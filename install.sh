#!/usr/bin/env bash
# Spine installer — AI coding setup for Cursor, Claude Code, Codex, and Copilot.
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
  "trailofbits/skills -s differential-review"
  "trailofbits/skills -s fp-check"
  "mattpocock/skills -s ubiquitous-language"
  "mattpocock/skills -s tdd"
  "vercel-labs/agent-browser -s agent-browser"
)

# MCP servers previously installed by Spine — removed on next run.
# Add server names here when replacing or dropping an MCP server.
RETIRED_MCP_SERVERS=()

# Agent names previously used by Spine — cleaned up on next run.
# Add names here when renaming an agent to ensure cross-provider cleanup.
RETIRED_AGENT_NAMES=("worker" "second-opinion")

# Skill names previously used by Spine — cleaned up on next run.
# Add names here when renaming a skill to ensure cross-provider cleanup.
RETIRED_SKILL_NAMES=("do-analyze" "do-consult")

# --- Helpers ---

info()     { printf "${_C_BLUE}==>${_C_RESET} %s\n" "$*" >&2; }
warn()     { printf "${_C_YELLOW}WARN:${_C_RESET} %s\n" "$*" >&2; }
error()    { printf "${_C_RED}ERROR:${_C_RESET} %s\n" "$*" >&2; }
done_msg() { printf "  ${_C_GREEN}✓${_C_RESET} %s\n" "$*" >&2; }

# Per-tool progressive output: each tool_add reprints the line, tool_done finalizes it.
_tool_current="" _tool_features=""
tool_start() { _tool_current="$1"; _tool_features=""; }
tool_add() {
  local f="$1"
  _tool_features="${_tool_features:+${_tool_features}, }$f"
  # Overwrite current line with updated feature list
  printf "\r  ${_C_GREEN}✓${_C_RESET} %s: %s" "$_tool_current" "$_tool_features" >&2
}
tool_done() {
  if [ -n "$_tool_features" ]; then
    # Final newline to lock the line
    printf "\n" >&2
  fi
  _tool_current="" _tool_features=""
}

# Run a command silently; on failure show captured output then return 1.
quiet() { local out; out=$("$@" 2>&1) || { echo "$out" >&2; return 1; }; }

# Step progress: step "1/7" "Checking dependencies"
step() { printf "\n${_C_BLUE}[%s]${_C_RESET} %s\n" "$1" "$2" >&2; }

# --- Dependency detection ---

# Check whether a python command reports Python >= 3.9.
python39_plus() {
  local python_cmd="$1"
  local version major minor

  command -v "$python_cmd" >/dev/null 2>&1 || return 1
  version=$("$python_cmd" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null) || return 1
  major=${version%%.*}
  minor=${version#*.}

  [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 9 ]; }
}

# Check if a tool binary is on PATH.
# Handles formula-to-binary name differences (e.g., ripgrep → rg).
dep_present() {
  case "$1" in
    python3)   python39_plus python3 || python39_plus python ;;
    ripgrep)   command -v rg        >/dev/null 2>&1 ;;
    ast-grep)  command -v ast-grep  >/dev/null 2>&1 || command -v sg >/dev/null 2>&1 ;;
    node)      command -v node      >/dev/null 2>&1 || command -v nodejs >/dev/null 2>&1 ;;
    coreutils) command -v gtimeout  >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1 ;;
    *)         command -v "$1"      >/dev/null 2>&1 ;;
  esac
}

has_brew() { command -v brew >/dev/null 2>&1; }

brew_formula_name() {
  case "$1" in
    python3)   echo "python" ;;
    tokenizer) echo "zahidcakici/tap/tokenizer" ;;
    *)         echo "$1" ;;
  esac
}

# Install a Homebrew formula if not already on PATH or installed via brew.
brew_install_if_missing() {
  local formula="$1"
  local brew_formula

  brew_formula=$(brew_formula_name "$formula")

  dep_present "$formula" && return 0
  brew list --formula "$brew_formula" >/dev/null 2>&1 && return 0
  if quiet brew install "$brew_formula" </dev/null; then
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

  # Installed tools Spine manages — keep machine-keyed and sync docs when changing these.
  local -a installed_tools=(
    git
    jq
    node
    python3
    uv
    ast-grep
    bun
    coreutils
    fd
    ni
    ripgrep
    sd
    shellcheck
    shfmt
    yq
    tokenizer
    agent-browser
    rtk
  )

  local use_brew=false
  if has_brew; then
    use_brew=true
  elif [ "$os" = "Darwin" ]; then
    warn "Homebrew not found — install it from https://brew.sh"
  fi

  # probe: direct binary install to ~/.local/bin (no Homebrew formula)
  install_probe

  # Collect missing deps (brew-managed tools only)
  for dep in "${installed_tools[@]}"; do
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
    # agent-browser requires Chrome for Testing (~500MB one-time download)
    if [[ " ${missing[*]} " == *" agent-browser "* ]]; then
      info "Run 'agent-browser install' to download Chrome for Testing (~500MB)"
    fi
  fi

  if ! $use_brew; then
    warn "Missing tools: ${missing[*]}"
    if [ "$os" = "Darwin" ]; then
      local brew_missing=()
      for dep in "${missing[@]}"; do
        brew_missing+=("$(brew_formula_name "$dep")")
      done
      echo "  After installing Homebrew, run:" >&2
      echo "    brew install ${brew_missing[*]}" >&2
    else
      echo "  Install via your package manager, e.g.:" >&2
      echo "    sudo apt install ${missing[*]}  # Debian/Ubuntu (fd→fd-find, node→nodejs, yq→snap or github.com/mikefarah/yq, coreutils is preinstalled)" >&2
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

# --- Install probe (direct binary, no Homebrew formula) ---

install_probe() {
  local PROBE_REPO="probelabs/probe"
  local INSTALL_DIR="$HOME/.local/bin"
  local MANIFEST="$HOME/.config/spine/tool-versions"

  # Platform guard — mac only
  local os; os="$(uname -s)"
  if [ "$os" != "Darwin" ]; then
    warn "probe: unsupported OS $os — skipping"
    return 0
  fi
  local arch; arch="$(uname -m)"
  local PLATFORM
  case "$arch" in
    arm64|aarch64) PLATFORM="aarch64-apple-darwin" ;;
    x86_64)        PLATFORM="x86_64-apple-darwin" ;;
    *)             warn "probe: unsupported architecture $arch — skipping"; return 0 ;;
  esac

  mkdir -p "$INSTALL_DIR"

  # Get latest release tag — gh CLI primary, curl fallback
  local latest_tag=""
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    latest_tag=$(gh release view --repo "$PROBE_REPO" --json tagName --jq '.tagName' 2>/dev/null) || true
  fi
  if [ -z "$latest_tag" ]; then
    local api_response
    api_response=$(curl -sS "https://api.github.com/repos/$PROBE_REPO/releases/latest" 2>/dev/null) || true
    if [ -n "$api_response" ]; then
      latest_tag=$(echo "$api_response" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
  fi
  if [ -z "$latest_tag" ]; then
    warn "probe: could not determine latest version — skipping"
    return 0
  fi

  # Version skip — check manifest + binary existence
  local installed_tag
  installed_tag=$(grep "^probe=" "$MANIFEST" 2>/dev/null | cut -d= -f2 | head -1) || true
  if [ "${installed_tag:-}" = "$latest_tag" ] && [ -x "$INSTALL_DIR/probe" ]; then
    return 0
  fi

  # Download
  info "Installing probe $latest_tag..."
  local tmpdir
  tmpdir=$(mktemp -d)

  local download_ok=false
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    if quiet gh release download "$latest_tag" --repo "$PROBE_REPO" \
        --pattern "probe-*-${PLATFORM}.tar.gz" \
        --pattern "probe-*-${PLATFORM}.tar.gz.sha256" \
        --dir "$tmpdir"; then
      download_ok=true
    fi
  fi
  if ! $download_ok; then
    # Discover asset URLs from release API
    local release_json asset_url sha_url
    release_json=$(curl -sS "https://api.github.com/repos/$PROBE_REPO/releases/tags/$latest_tag" 2>/dev/null) || true
    if [ -n "$release_json" ]; then
      asset_url=$(echo "$release_json" | grep "browser_download_url" | grep "${PLATFORM}.tar.gz\"" | grep -v '.sha256"' | sed -E 's/.*"(https[^"]+)".*/\1/' | head -1)
      sha_url=$(echo "$release_json" | grep "browser_download_url" | grep "${PLATFORM}.tar.gz.sha256\"" | sed -E 's/.*"(https[^"]+)".*/\1/' | head -1)
    fi
    if [ -n "${asset_url:-}" ] && [ -n "${sha_url:-}" ]; then
      if curl -fsSL -o "$tmpdir/$(basename "$asset_url")" "$asset_url" && \
         curl -fsSL -o "$tmpdir/$(basename "$sha_url")" "$sha_url"; then
        download_ok=true
      fi
    fi
  fi
  if ! $download_ok; then
    warn "probe: download failed — skipping"
    rm -rf "$tmpdir"
    return 0
  fi

  # Checksum verification
  if ! (cd "$tmpdir" && shasum -a 256 -c ./*.sha256 >/dev/null 2>&1); then
    warn "probe: checksum verification failed — skipping"
    rm -rf "$tmpdir"
    return 0
  fi

  # Extract and install
  tar -xzf "$tmpdir"/probe-*-"${PLATFORM}".tar.gz -C "$tmpdir"
  local extracted
  extracted=$(find "$tmpdir" -name probe -type f -not -name '*.gz' | head -1)
  if [ -z "$extracted" ]; then
    warn "probe: binary not found in archive — skipping"
    rm -rf "$tmpdir"
    return 0
  fi
  mv "$extracted" "$INSTALL_DIR/probe"
  chmod +x "$INSTALL_DIR/probe"

  # Write manifest — atomic tmpfile+mv
  local manifest_tmp
  manifest_tmp=$(mktemp)
  [ -f "$MANIFEST" ] && grep -v "^probe=" "$MANIFEST" > "$manifest_tmp" || true
  echo "probe=$latest_tag" >> "$manifest_tmp"
  mv "$manifest_tmp" "$MANIFEST"

  # Migration: remove old probe from /usr/local/bin
  if [ -f /usr/local/bin/probe ]; then
    if [ -O /usr/local/bin/probe ]; then
      rm /usr/local/bin/probe
    else
      warn "Old probe at /usr/local/bin/probe not user-owned — remove manually: sudo rm /usr/local/bin/probe"
    fi
  fi

  rm -rf "$tmpdir"
  done_msg "probe $latest_tag"
}

# --- Detect installed tools ---

detect_tools() {
  local tools=()

  # Cursor: config dir is sufficient (no standalone CLI binary)
  [ -d "$HOME/.cursor" ] && tools+=("cursor")

  # Claude Code / Codex / OpenCode: require CLI binary on PATH
  for tool in claude codex qwen copilot opencode; do
    if command -v "$tool" >/dev/null 2>&1; then
      tools+=("$tool")
    elif [ -d "$HOME/.$tool" ]; then
      warn "$tool: config directory exists but CLI not found on PATH — skipping"
    fi
  done

  if [ ${#tools[@]} -eq 0 ]; then
    warn "No AI coding tools found (cursor, claude, codex, qwen, copilot, opencode)"
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

  # Create empty AGENTS.md for user customizations (never overwritten)
  [ -f "$spine_dir/AGENTS.md" ] || touch "$spine_dir/AGENTS.md"

  # Always sync .env.example; seed .env from it if absent
  if [ -f "$src/env.example" ]; then
    cp "$src/env.example" "$spine_dir/.env.example"
    if [ ! -f "$spine_dir/.env" ]; then
      cp "$spine_dir/.env.example" "$spine_dir/.env"
      done_msg "Created .env from template (edit ~/.config/spine/.env to configure)"
    fi
  fi

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
  local custom_ref='@~/.config/spine/AGENTS.md'

  # OpenCode: agents live in ~/.config/opencode/agents/ (XDG layout)
  if [ "$tool" = "opencode" ]; then
    target="$HOME/.config/opencode"
  fi

  mkdir -p "$target"

  # Guardrails: write @reference to provider root file
  # Copilot/OpenCode: no root file needed
  local root_file=""
  case "$tool" in
    claude)   root_file="$target/CLAUDE.md" ;;
    qwen)     root_file="$target/QWEN.md" ;;
    copilot)  ;;  # skip — Copilot loads AGENTS.md natively
    opencode) ;;  # skip — OpenCode uses agent frontmatter only
    *)        root_file="$target/AGENTS.md" ;;
  esac

  if [ -z "$root_file" ]; then
    : # no root file for this tool
  elif [ ! -f "$root_file" ]; then
    # Fresh install
    printf '%s\n' "$spine_ref" "$custom_ref" > "$root_file"
  elif head -1 "$root_file" | grep -q '^@.*SPINE\.md$'; then
    # Already managed — ensure AGENTS.md ref present (upgrade path)
    if ! grep -q "$custom_ref" "$root_file"; then
      backup_if_exists "$root_file"
      local tmp; tmp=$(mktemp)
      head -1 "$root_file" > "$tmp"
      echo "$custom_ref" >> "$tmp"
      tail -n +2 "$root_file" >> "$tmp"
      mv "$tmp" "$root_file"
    fi
  elif diff -q "$root_file" "$spine_dir/SPINE.md" >/dev/null 2>&1 || \
       head -1 "$root_file" | grep -q '^# \(AGENTS\|SPINE\)\.md$'; then
    # Spine-managed content (current or pre-rename) — safe to replace entirely
    backup_if_exists "$root_file"
    printf '%s\n' "$spine_ref" "$custom_ref" > "$root_file"
  else
    # User has custom content — prepend @reference, keep existing content
    backup_if_exists "$root_file"
    local tmp
    tmp=$(mktemp)
    printf '%s\n%s\n\n' "$spine_ref" "$custom_ref" > "$tmp"
    cat "$root_file" >> "$tmp"
    mv "$tmp" "$root_file"
  fi

  # Agents: Codex uses generated TOML; Cursor uses generated .md; Claude uses symlinks
  mkdir -p "$target/agents"
  if [ "$tool" = "codex" ]; then
    # Remove old .md symlinks (spine-managed only)
    for md in "$target/agents/"*.md; do
      [ -L "$md" ] || continue
      local dest
      dest=$(readlink "$md")
      [[ "$dest" == *".config/spine/"* ]] && rm "$md"
    done
    # Generate TOML role configs
    for agent in "$spine_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      generate_codex_agent_toml "$agent" "$target/agents"
    done
    # Patch config.toml with agent registrations
    patch_codex_config "$target" "$spine_dir/agents"
  elif [ "$tool" = "cursor" ]; then
    # Remove old symlinks (spine-managed only) — upgrade from symlink to generated .md
    for md in "$target/agents/"*.md; do
      [ -L "$md" ] || continue
      local dest
      dest=$(readlink "$md")
      [[ "$dest" == *".config/spine/"* ]] && rm "$md"
    done
    # Generate Cursor agent .md files
    for agent in "$spine_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      generate_cursor_agent_md "$agent" "$target/agents"
    done
  elif [ "$tool" = "qwen" ]; then
    # Remove old symlinks (spine-managed only) — upgrade from symlink to generated .md
    for md in "$target/agents/"*.md; do
      [ -L "$md" ] || continue
      local dest
      dest=$(readlink "$md")
      [[ "$dest" == *".config/spine/"* ]] && rm "$md"
    done
    # Generate Qwen agent .md files
    for agent in "$spine_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      generate_qwen_agent_md "$agent" "$target/agents"
    done
  elif [ "$tool" = "copilot" ]; then
    # Remove old symlinks (spine-managed only) — upgrade from symlink to generated .md
    for md in "$target/agents/"*.md; do
      [ -L "$md" ] || continue
      local dest
      dest=$(readlink "$md")
      [[ "$dest" == *".config/spine/"* ]] && rm "$md"
    done
    # Generate Copilot agent .md files
    for agent in "$spine_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      generate_copilot_agent_md "$agent" "$target/agents"
    done
  elif [ "$tool" = "opencode" ]; then
    # Generate OpenCode agent .md files (with model: in frontmatter)
    for agent in "$spine_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      generate_opencode_agent_md "$agent" "$target/agents"
    done
  else
    for agent in "$spine_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      local name
      name=$(basename "$agent")
      if [ -f "$target/agents/$name" ] && [ ! -L "$target/agents/$name" ]; then
        backup_if_exists "$target/agents/$name"
      fi
      ln -sf "../../.config/spine/agents/$name" "$target/agents/$name"
    done
  fi

  tool_add "guardrails, agents"

  # Qwen Code extras: configure context.fileName to load both QWEN.md and AGENTS.md
  if [ "$tool" = "qwen" ] && command -v jq &>/dev/null; then
    local qwen_settings="$target/settings.json"
    if [ -f "$qwen_settings" ]; then
      local tmp
      tmp=$(mktemp)
      if jq '.context.fileName = ["QWEN.md", "AGENTS.md"]' "$qwen_settings" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$qwen_settings"
        tool_add "context.fileName"
      else
        rm -f "$tmp"
        warn "Failed to patch $qwen_settings — set context.fileName manually"
      fi
    else
      printf '{"context":{"fileName":["QWEN.md","AGENTS.md"]}}\n' > "$qwen_settings"
      tool_add qwen "context.fileName"
    fi
  fi

  # Claude Code extras: plugin (hooks + skills)
  if [ "$tool" = "claude" ]; then
    install_claude_plugin "$src" "$target"
  fi
}

# --- Claude Code plugin (hooks + skills) ---

install_claude_plugin() {
  local src="$1" target="$2"

  # Determine marketplace source: local path for persistent checkouts, GitHub for downloads.
  # Check _SPINE_CLEANUP_DIR to distinguish local checkouts from git-cloned temp dirs.
  local marketplace_src="kenoxa/spine"
  [ -z "${_SPINE_CLEANUP_DIR:-}" ] && [ -d "$src/.git" ] && marketplace_src="$src"

  # Attempt plugin installation
  if quiet claude plugin marketplace add "$marketplace_src" && \
     quiet claude plugin install spine@kenoxa; then
    tool_add "plugin"
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

# --- RTK (token optimization proxy) ---

# Minimum RTK version required (permissionDecision bypass fix).
RTK_MIN_VERSION="0.33.1"

_rtk_ready=false
install_rtk_once() {
  $_rtk_ready && return 0

  if ! command -v rtk &>/dev/null; then
    warn "rtk not found — skipping token optimization setup"
    return 1
  fi

  # Version check: require >= 0.33.1 (permissionDecision bypass fix)
  local rtk_version
  rtk_version=$(rtk --version 2>/dev/null | awk '{print $2}')
  if [ -n "$rtk_version" ] && ! version_gte "$rtk_version" "$RTK_MIN_VERSION"; then
    warn "rtk $rtk_version is below minimum $RTK_MIN_VERSION — skipping (brew upgrade rtk)"
    return 1
  fi

  # Disable telemetry by default
  local rtk_config_dir="$HOME/.config/rtk"
  local rtk_config="$rtk_config_dir/config.toml"
  if [ ! -f "$rtk_config" ]; then
    mkdir -p "$rtk_config_dir"
    cat > "$rtk_config" << 'TOML'
[telemetry]
enabled = false
TOML
  fi

  _rtk_ready=true
}

_install_rtk_single() {
  local tool="$1"
  install_rtk_once || return 0
  case "$tool" in
    claude)
      quiet rtk init -g --auto-patch && tool_add "rtk" || warn "rtk init -g failed"
      _rtk_patch_claude_hook_path
      ;;
    cursor)
      quiet rtk init -g --agent cursor && tool_add "rtk" || warn "rtk init --agent cursor failed"
      ;;
    codex)
      quiet rtk init -g --codex && tool_add "rtk" || warn "rtk init --codex failed"
      ;;
    qwen)
      _rtk_copy_codex_template "$HOME/.$tool"
      _rtk_add_root_ref "$HOME/.$tool" "$tool"
      tool_add "rtk"
      ;;
    copilot)
      # Copilot: project-scoped only — deferred
      ;;
    opencode)
      quiet rtk init -g --opencode && tool_add "rtk" || warn "rtk init --opencode failed"
      ;;
  esac
}

# Patch Claude Code settings.json to include absolute rtk path in hook command.
# Workaround for RTK issue #685: hook subprocess PATH excludes /opt/homebrew/bin.
_rtk_patch_claude_hook_path() {
  local settings="$HOME/.claude/settings.json"
  [ -f "$settings" ] || return 0
  command -v jq &>/dev/null || return 0

  local rtk_path
  rtk_path=$(command -v rtk)

  # Check if hook exists and needs patching (contains rtk-rewrite but no absolute path)
  if ! jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command | test("rtk-rewrite"))' "$settings" &>/dev/null; then
    return 0  # no RTK hook found
  fi

  # Already patched with PATH= prefix? Skip.
  if jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command | test("^PATH="))' "$settings" &>/dev/null; then
    return 0
  fi

  local rtk_dir
  rtk_dir=$(dirname "$rtk_path")
  local tmp
  tmp=$(mktemp)

  # Prepend PATH with rtk's directory to the hook command
  if jq --arg dir "$rtk_dir" '
    .hooks.PreToolUse |= map(
      .hooks |= map(
        if (.command | test("rtk-rewrite"))
        then .command = "PATH=\"" + $dir + ":$PATH\" " + .command
        else . end
      )
    )
  ' "$settings" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
    done_msg "rtk: patched claude hook with absolute PATH"
  else
    rm -f "$tmp"
  fi
}

# Add @RTK.md reference to provider root file if not already present.
_rtk_add_root_ref() {
  local target="$1" tool="$2"
  local rtk_ref="@~/.${tool}/RTK.md"
  local root_file=""
  case "$tool" in
    qwen)   root_file="$target/QWEN.md" ;;
    *)      root_file="$target/AGENTS.md" ;;
  esac
  [ -n "$root_file" ] && [ -f "$root_file" ] || return 0
  grep -qF "$rtk_ref" "$root_file" && return 0  # already referenced
  echo "$rtk_ref" >> "$root_file"
}

# Copy RTK instruction template from Codex (created by rtk init -g --codex).
_rtk_copy_codex_template() {
  local target="$1"
  local rtk_md="$target/RTK.md"
  local codex_rtk="$HOME/.codex/RTK.md"

  [ -f "$rtk_md" ] && return 0  # already exists
  if [ ! -f "$codex_rtk" ]; then
    warn "rtk: codex template not found — skipping $tool RTK instructions"
    return 0
  fi
  cp "$codex_rtk" "$rtk_md"
}

# Compare semver: returns 0 if $1 >= $2
version_gte() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]
}

# --- MCP server helpers ---

source_spine_env() {
  local env_file="$HOME/.config/spine/.env"
  [ -f "$env_file" ] || return 0

  # shellcheck disable=SC1090
  . "$env_file" 2>/dev/null || { warn "Failed to source $env_file — using keyless mode"; return 0; }

  # Ensure env vars are available in future shells (Codex reads at runtime)
  if command -v zsh &>/dev/null; then
    local zshenv="$HOME/.zshenv"
    if ! grep -qF '/.config/spine/.env' "$zshenv" 2>/dev/null; then
      # shellcheck disable=SC2016  # intentional: $HOME expands at shell startup, not install time
      echo '[ -f "$HOME/.config/spine/.env" ] && source "$HOME/.config/spine/.env"' >> "$zshenv"
      done_msg "Added spine env to ~/.zshenv"
    fi
  fi
}

mcp_add_claude() {
  local name="$1" url="$2"; shift 2
  # Remove first for idempotency — claude mcp add fails if entry already exists
  quiet claude mcp remove "$name" --scope user 2>/dev/null || true
  if quiet claude mcp add --transport http --scope user "$name" "$url" "$@"; then
    tool_add "MCP:$name"
  else
    warn "Failed to add MCP server $name to claude"
    echo "  Run manually: claude mcp add --transport http --scope user $name $url $*" >&2
  fi
}

mcp_add_codex() {
  local name="$1" url="$2"; shift 2
  if quiet codex mcp add "$name" --url "$url" "$@"; then
    tool_add "MCP:$name"
  else
    warn "Failed to add MCP server $name to codex"
    echo "  Run manually: codex mcp add $name --url $url $*" >&2
  fi
}

mcp_add_qwen() {
  local name="$1" url="$2"; shift 2
  # Remove first for idempotency — qwen mcp add may fail if entry already exists
  quiet qwen mcp remove "$name" --scope user 2>/dev/null || true
  # Strip MCP API key env vars so qwen stores ${VAR} references for runtime resolution
  # instead of resolving them at add-time (qwen expands env vars in -H values if set)
  if quiet env -u CONTEXT7_API_KEY -u EXA_API_KEY \
      qwen mcp add --transport http --scope user --trust "$name" "$url" "$@"; then
    tool_add "MCP:$name"
  else
    warn "Failed to add MCP server $name to qwen"
    echo "  Run manually: qwen mcp add --transport http --scope user --trust $name $url $*" >&2
  fi
}

mcp_add_cursor() {
  local c7_url="$1" c7_key="$2" exa_url="$3" exa_key="$4"
  local mcp_file="$HOME/.cursor/mcp.json"

  if ! command -v jq &>/dev/null; then
    warn "jq not found — cannot configure Cursor MCP servers"
    return 0
  fi

  if [ -f "$mcp_file" ] && ! jq empty "$mcp_file" 2>/dev/null; then
    warn "Invalid JSON in $mcp_file — skipping Cursor MCP configuration"
    return 0
  fi

  [ -f "$mcp_file" ] || echo '{}' > "$mcp_file"

  local tmp
  tmp=$(mktemp)
  # Cursor supports ${env:NAME} interpolation in headers — use runtime references, not baked values
  jq --arg c7url "$c7_url" --arg c7key "$c7_key" \
     --arg exaurl "$exa_url" --arg exakey "$exa_key" '
    .mcpServers //= {} |
    .mcpServers.context7 = (
      {url: $c7url} + if $c7key != "" then {headers: {"Authorization": "Bearer ${env:CONTEXT7_API_KEY}"}} else {} end
    ) |
    .mcpServers.exa = (
      {url: $exaurl} + if $exakey != "" then {headers: {"Authorization": "Bearer ${env:EXA_API_KEY}"}} else {} end
    )
  ' "$mcp_file" > "$tmp"

  if jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$mcp_file"
    tool_add "MCP:context7, MCP:exa"
  else
    warn "Generated invalid JSON — $mcp_file left unchanged"
    rm -f "$tmp"
    return 0
  fi
}

mcp_add_copilot() {
  local c7_url="$1" c7_key="$2" exa_url="$3" exa_key="$4"
  local mcp_file="$HOME/.copilot/mcp-config.json"

  if ! command -v jq &>/dev/null; then
    warn "jq not found — cannot configure Copilot MCP servers"
    return 0
  fi

  if [ -f "$mcp_file" ] && ! jq empty "$mcp_file" 2>/dev/null; then
    warn "Invalid JSON in $mcp_file — skipping Copilot MCP configuration"
    return 0
  fi

  [ -f "$mcp_file" ] || { mkdir -p "$(dirname "$mcp_file")"; echo '{}' > "$mcp_file"; }

  local tmp
  tmp=$(mktemp)
  # Copilot supports ${env:NAME} interpolation in headers — use runtime references, not baked values
  jq --arg c7url "$c7_url" --arg c7key "$c7_key" \
     --arg exaurl "$exa_url" --arg exakey "$exa_key" '
    .mcpServers //= {} |
    .mcpServers.context7 = (
      {url: $c7url} + if $c7key != "" then {headers: {"Authorization": "Bearer ${env:CONTEXT7_API_KEY}"}} else {} end
    ) |
    .mcpServers.exa = (
      {url: $exaurl} + if $exakey != "" then {headers: {"Authorization": "Bearer ${env:EXA_API_KEY}"}} else {} end
    )
  ' "$mcp_file" > "$tmp"

  if jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$mcp_file"
    tool_add "MCP:context7, MCP:exa"
  else
    warn "Generated invalid JSON — $mcp_file left unchanged"
    rm -f "$tmp"
    return 0
  fi
}

mcp_add_opencode() {
  local c7_url="$1" c7_key="$2" exa_url="$3" exa_key="$4"
  local config_dir="$HOME/.config/opencode"
  local config_file="$config_dir/opencode.json"

  if ! command -v jq &>/dev/null; then
    warn "jq not found — cannot configure OpenCode MCP servers"
    return 0
  fi

  mkdir -p "$config_dir"
  [ -f "$config_file" ] || echo '{}' > "$config_file"

  if [ -f "$config_file" ] && ! jq empty "$config_file" 2>/dev/null; then
    warn "Invalid JSON in $config_file — skipping OpenCode MCP configuration"
    return 0
  fi

  # OpenCode uses {env:NAME} runtime references — key args gate whether headers are added
  local tmp
  tmp=$(mktemp)
  jq --arg c7url "$c7_url" --arg c7key "$c7_key" \
     --arg exaurl "$exa_url" --arg exakey "$exa_key" '
    .mcp //= {} |
    .mcp.context7 = (
      {type: "remote", url: $c7url} + if $c7key != "" then {headers: {"Authorization": "Bearer {env:CONTEXT7_API_KEY}"}} else {} end
    ) |
    .mcp.exa = (
      {type: "remote", url: $exaurl} + if $exakey != "" then {headers: {"Authorization": "Bearer {env:EXA_API_KEY}"}} else {} end
    )
  ' "$config_file" > "$tmp"

  if jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$config_file"
    tool_add "MCP:context7, MCP:exa"
  else
    warn "Generated invalid JSON — $config_file left unchanged"
    rm -f "$tmp"
    return 0
  fi
}

_mcp_ready=false
_mcp_c7_url="" _mcp_exa_url=""
_mcp_c7_claude_auth=() _mcp_exa_claude_auth=()
_mcp_c7_codex_auth=() _mcp_exa_codex_auth=()

install_mcp_once() {
  $_mcp_ready && return 0

  source_spine_env

  _mcp_c7_url="https://mcp.context7.com/mcp"
  _mcp_exa_url="https://mcp.exa.ai/mcp?tools=get_code_context_exa,web_search_exa"

  if [ -n "${CONTEXT7_API_KEY:-}" ]; then
    # shellcheck disable=SC2016  # intentional: env var resolves at runtime, not install time
    _mcp_c7_claude_auth=(--header 'Authorization: Bearer ${CONTEXT7_API_KEY}')
    _mcp_c7_codex_auth=(--bearer-token-env-var CONTEXT7_API_KEY)
  fi
  if [ -n "${EXA_API_KEY:-}" ]; then
    # shellcheck disable=SC2016
    _mcp_exa_claude_auth=(--header 'Authorization: Bearer ${EXA_API_KEY}')
    _mcp_exa_codex_auth=(--bearer-token-env-var EXA_API_KEY)
  fi

  _mcp_ready=true
}

_install_mcp_single() {
  local tool="$1"
  install_mcp_once

  case "$tool" in
    claude)
      mcp_add_claude "context7" "$_mcp_c7_url" "${_mcp_c7_claude_auth[@]}"
      mcp_add_claude "exa" "$_mcp_exa_url" "${_mcp_exa_claude_auth[@]}"
      ;;
    codex)
      mcp_add_codex "context7" "$_mcp_c7_url" "${_mcp_c7_codex_auth[@]}"
      mcp_add_codex "exa" "$_mcp_exa_url" "${_mcp_exa_codex_auth[@]}"
      ;;
    cursor)
      mcp_add_cursor "$_mcp_c7_url" "${CONTEXT7_API_KEY:-}" "$_mcp_exa_url" "${EXA_API_KEY:-}"
      if command -v agent &>/dev/null; then
        quiet agent mcp enable context7 2>/dev/null || true
        quiet agent mcp enable exa 2>/dev/null || true
        tool_add "MCP approved"
      fi
      ;;
    qwen)
      local c7_qwen_auth=() exa_qwen_auth=()
      if [ -n "${CONTEXT7_API_KEY:-}" ]; then
        # shellcheck disable=SC2016
        c7_qwen_auth=(-H 'Authorization: Bearer ${CONTEXT7_API_KEY}')
      fi
      if [ -n "${EXA_API_KEY:-}" ]; then
        # shellcheck disable=SC2016
        exa_qwen_auth=(-H 'Authorization: Bearer ${EXA_API_KEY}')
      fi
      mcp_add_qwen "context7" "$_mcp_c7_url" "${c7_qwen_auth[@]}"
      mcp_add_qwen "exa" "$_mcp_exa_url" "${exa_qwen_auth[@]}"
      ;;
    copilot)
      mcp_add_copilot "$_mcp_c7_url" "${CONTEXT7_API_KEY:-}" "$_mcp_exa_url" "${EXA_API_KEY:-}"
      ;;
    opencode)
      mcp_add_opencode "$_mcp_c7_url" "${CONTEXT7_API_KEY:-}" "$_mcp_exa_url" "${EXA_API_KEY:-}"
      ;;
  esac
}

install_mcp_servers() {
  local detected_tools=("$@")
  for tool in "${detected_tools[@]}"; do
    _install_mcp_single "$tool"
  done

  # Remove retired MCP servers
  if [ ${#RETIRED_MCP_SERVERS[@]} -gt 0 ]; then
    for name in "${RETIRED_MCP_SERVERS[@]}"; do
      for tool in "${detected_tools[@]}"; do
        case "$tool" in
          claude) quiet claude mcp remove "$name" --scope user 2>/dev/null || true ;;
          codex)  quiet codex mcp remove "$name" 2>/dev/null || true ;;
          qwen)   quiet qwen mcp remove "$name" --scope user 2>/dev/null || true ;;
          cursor)
            if [ -f "$HOME/.cursor/mcp.json" ] && command -v jq &>/dev/null; then
              local tmp
              tmp=$(mktemp)
              if jq --arg n "$name" 'del(.mcpServers[$n])' "$HOME/.cursor/mcp.json" > "$tmp"; then
                mv "$tmp" "$HOME/.cursor/mcp.json"
              else
                rm -f "$tmp"
              fi
            fi
            command -v agent &>/dev/null && quiet agent mcp disable "$name" 2>/dev/null || true
            ;;
          copilot)
            if [ -f "$HOME/.copilot/mcp-config.json" ] && command -v jq &>/dev/null; then
              local tmp
              tmp=$(mktemp)
              if jq --arg n "$name" 'del(.mcpServers[$n])' "$HOME/.copilot/mcp-config.json" > "$tmp"; then
                mv "$tmp" "$HOME/.copilot/mcp-config.json"
              else
                rm -f "$tmp"
              fi
            fi
            ;;
        esac
      done
      done_msg "Removed retired MCP server: $name"
    done
  fi
}

# --- Backup helper ---

backup_if_exists() {
  local file="$1"
  if [ -e "$file" ] || [ -L "$file" ]; then
    # Skip backup for spine-managed files — we own them and will overwrite
    if [ -f "$file" ] && head -3 "$file" | grep -q 'spine:managed' 2>/dev/null; then
      return 0
    fi
    cp -L "$file" "${file}.bak" 2>/dev/null || true
  fi
}

# --- Codex TOML agent generation ---

# Parse YAML frontmatter from an agent markdown file.
# Sets: _agent_name, _agent_description, _agent_model, _agent_effort,
#       _agent_readonly, _agent_skills (comma-separated), _agent_body (everything after closing ---)
parse_agent_frontmatter() {
  local md_file="$1"
  _agent_name="" _agent_description="" _agent_model="" _agent_effort=""
  _agent_readonly="" _agent_skills="" _agent_body=""

  # Fields via yq (--front-matter=extract strips body, outputs frontmatter as YAML)
  _agent_name=$(yq --front-matter=extract '.name // ""' "$md_file")
  _agent_description=$(yq --front-matter=extract '.description // "" | sub("\n$", "")' "$md_file")
  _agent_model=$(yq --front-matter=extract '.model // ""' "$md_file")
  _agent_effort=$(yq --front-matter=extract '.effort // ""' "$md_file")
  _agent_readonly=$(yq --front-matter=extract '.readonly // ""' "$md_file")
  _agent_skills=$(yq --front-matter=extract '.skills // [] | join(", ")' "$md_file")

  # Body: while-read loop preserved (yq cannot extract post-frontmatter text;
  # awk alternatives break leading-blank-line parity — see challenge BF-1)
  local in_fm=false fm_done=false
  while IFS= read -r line || [ -n "$line" ]; do
    if ! $fm_done; then
      if [ "$line" = "---" ]; then
        if $in_fm; then fm_done=true; fi
        in_fm=true
      fi
    else
      _agent_body="${_agent_body:+$_agent_body
}$line"
    fi
  done < "$md_file"

  [ -n "$_agent_name" ] || _agent_name="$(basename "$md_file" .md)"
}

# Canonical mapping reference: docs/model-selection.md
# Map a canonical model tier to a provider-specific model name.
# Sets: _mapped_model
map_model_for_provider() {
  local model="$1" provider="$2"
  case "$model:$provider" in
    opus:codex)    _mapped_model="gpt-5.4" ;;
    opus:cursor)   _mapped_model="composer-2" ;;
    sonnet:codex)  _mapped_model="gpt-5.4" ;;
    sonnet:cursor) _mapped_model="auto" ;;
    haiku:codex)   _mapped_model="gpt-5.4-mini" ;;  # ideal: gpt-5.4-nano (unavailable on current Codex subscription)
    haiku:cursor)  _mapped_model="fast" ;;
    opus:qwen)     _mapped_model="qwen3.5-plus" ;;
    sonnet:qwen)   _mapped_model="qwen3-coder-plus" ;;
    haiku:qwen)    _mapped_model="coder-model" ;;
    opus:copilot)    _mapped_model="gpt-5.4" ;;
    sonnet:copilot)  _mapped_model="gpt-5.4" ;;
    haiku:copilot)   _mapped_model="gpt-5.4-mini" ;;
    opus:opencode)     _mapped_model="opencode-go/glm-5" ;;
    sonnet:opencode)   _mapped_model="opencode-go/minimax-m2.7" ;;
    haiku:opencode)    _mapped_model="opencode/minimax-m2.5-free" ;;
    inherit:*|"":*) _mapped_model="" ;;
    *) warn "Unknown model '$model' for provider '$provider'"; _mapped_model="" ;;
  esac
}

# Map a canonical effort level to a provider-specific value.
# Sets: _mapped_effort
map_effort_for_provider() {
  local effort="$1" provider="$2"
  case "$effort:$provider" in
    max:codex)    _mapped_effort="high" ;;
    high:codex)   _mapped_effort="high" ;;
    medium:codex) _mapped_effort="medium" ;;
    max:copilot)    _mapped_effort="high" ;;
    high:copilot)   _mapped_effort="high" ;;
    medium:copilot) _mapped_effort="medium" ;;
    low:copilot)    _mapped_effort="low" ;;
    max:opencode)    _mapped_effort="max" ;;
    high:opencode)   _mapped_effort="high" ;;
    medium:opencode) _mapped_effort="medium" ;;
    low:opencode)    _mapped_effort="minimal" ;;
    *) _mapped_effort="" ;;
  esac
}

# Generate a Codex TOML role config from an agent markdown file.
# Usage: generate_codex_agent_toml <agent.md> <output-dir>
generate_codex_agent_toml() {
  local md_file="$1" out_dir="$2"
  parse_agent_frontmatter "$md_file"

  if [ -z "$_agent_body" ]; then
    warn "No body in $(basename "$md_file") — skipping TOML generation"
    return 0
  fi

  # Build developer_instructions with optional skills preamble
  local instructions="$_agent_body"
  if [ -n "$_agent_skills" ]; then
    instructions="Load the following skill(s): $_agent_skills

$_agent_body"
  fi

  local tmp out_file="$out_dir/$_agent_name.toml"
  tmp=$(mktemp "$out_dir/spine-tmp.XXXXXX")

  {
    echo "# spine:managed -- do not edit"
    map_model_for_provider "$_agent_model" codex
    [ -n "$_mapped_model" ] && echo "model = \"$_mapped_model\""
    map_effort_for_provider "$_agent_effort" codex
    [ -n "$_mapped_effort" ] && echo "model_reasoning_effort = \"$_mapped_effort\""
    [ "$_agent_readonly" = "true" ] && echo 'sandbox_mode = "read-only"'
    if [[ "$instructions" == *"'''"* ]]; then
      echo 'developer_instructions = """'
      printf '%s\n' "$instructions"
      echo '"""'
    else
      echo "developer_instructions = '''"
      printf '%s\n' "$instructions"
      echo "'''"
    fi
  } > "$tmp"

  mv "$tmp" "$out_file"
}

# --- Cursor agent generation ---

# Generate a Cursor agent .md from an agent markdown file.
# Usage: generate_cursor_agent_md <agent.md> <output-dir>
generate_cursor_agent_md() {
  local md_file="$1" out_dir="$2"
  parse_agent_frontmatter "$md_file"

  if [ -z "$_agent_body" ]; then
    warn "No body in $(basename "$md_file") — skipping Cursor agent generation"
    return 0
  fi

  # Build body with optional skills preamble (Cursor ignores skills: frontmatter)
  local body="$_agent_body"
  if [ -n "$_agent_skills" ]; then
    body="Load the following skill(s): $_agent_skills

$_agent_body"
  fi

  local tmp out_file="$out_dir/$_agent_name.md"
  tmp=$(mktemp "$out_dir/spine-tmp.XXXXXX")

  {
    echo '---'
    echo '# spine:managed — do not edit'
    echo "name: $_agent_name"
    printf 'description: >-\n  %s\n' "$_agent_description"
    map_model_for_provider "$_agent_model" cursor
    [ -n "$_mapped_model" ] && echo "model: $_mapped_model"
    # effort: omitted — Cursor has no effort parameter (subagent or CLI)
    # skills: omitted — Cursor ignores frontmatter skills; embedded in body above
    [ "$_agent_readonly" = "true" ] && echo 'readonly: true'
    echo '---'
    echo ""
    printf '%s\n' "$body"
  } > "$tmp"

  if [ -f "$out_file" ] && [ ! -L "$out_file" ]; then
    backup_if_exists "$out_file"
  fi
  mv "$tmp" "$out_file"
}

# --- Qwen agent generation ---

# Generate a Qwen Code agent .md from an agent markdown file.
# Qwen agents use name + description frontmatter only (no model, effort, readonly, tools).
# Usage: generate_qwen_agent_md <agent.md> <output-dir>
generate_qwen_agent_md() {
  local md_file="$1" out_dir="$2"
  parse_agent_frontmatter "$md_file"

  if [ -z "$_agent_body" ]; then
    warn "No body in $(basename "$md_file") — skipping Qwen agent generation"
    return 0
  fi

  # Build body with optional skills preamble (Qwen ignores skills: frontmatter)
  local body="$_agent_body"
  if [ -n "$_agent_skills" ]; then
    body="Load the following skill(s): $_agent_skills

$_agent_body"
  fi

  local tmp out_file="$out_dir/$_agent_name.md"
  tmp=$(mktemp "$out_dir/spine-tmp.XXXXXX")

  {
    echo '---'
    echo '# spine:managed — do not edit'
    echo "name: $_agent_name"
    printf 'description: >-\n  %s\n' "$_agent_description"
    echo '---'
    echo ""
    printf '%s\n' "$body"
  } > "$tmp"

  if [ -f "$out_file" ] && [ ! -L "$out_file" ]; then
    backup_if_exists "$out_file"
  fi
  mv "$tmp" "$out_file"
}

# --- Copilot agent generation ---

# Generate a Copilot CLI agent .md from an agent markdown file.
# Copilot agents use name + description frontmatter only (no model, effort, readonly, tools).
# Usage: generate_copilot_agent_md <agent.md> <output-dir>
generate_copilot_agent_md() {
  local md_file="$1" out_dir="$2"
  parse_agent_frontmatter "$md_file"

  if [ -z "$_agent_body" ]; then
    warn "No body in $(basename "$md_file") — skipping Copilot agent generation"
    return 0
  fi

  # Build body with optional skills preamble (Copilot ignores skills: frontmatter)
  local body="$_agent_body"
  if [ -n "$_agent_skills" ]; then
    body="Load the following skill(s): $_agent_skills

$_agent_body"
  fi

  local tmp out_file="$out_dir/$_agent_name.md"
  tmp=$(mktemp "$out_dir/spine-tmp.XXXXXX")

  {
    echo '---'
    echo '# spine:managed — do not edit'
    echo "name: $_agent_name"
    printf 'description: >-\n  %s\n' "$_agent_description"
    echo '---'
    echo ""
    printf '%s\n' "$body"
  } > "$tmp"

  if [ -f "$out_file" ] && [ ! -L "$out_file" ]; then
    backup_if_exists "$out_file"
  fi
  mv "$tmp" "$out_file"
}

# --- OpenCode agent generation ---

# Generate an OpenCode agent .md from an agent markdown file.
# OpenCode agents support model: in frontmatter (unlike Qwen/Copilot which omit it).
# Output: ~/.config/opencode/agents/<name>.md
# Usage: generate_opencode_agent_md <agent.md> <output-dir>
generate_opencode_agent_md() {
  local md_file="$1" out_dir="$2"
  parse_agent_frontmatter "$md_file"

  if [ -z "$_agent_body" ]; then
    warn "No body in $(basename "$md_file") — skipping OpenCode agent generation"
    return 0
  fi

  # Build body with optional skills preamble
  local body="$_agent_body"
  if [ -n "$_agent_skills" ]; then
    body="Load the following skill(s): $_agent_skills

$_agent_body"
  fi

  map_model_for_provider "$_agent_model" opencode

  local tmp out_file="$out_dir/$_agent_name.md"
  tmp=$(mktemp "$out_dir/spine-tmp.XXXXXX")

  {
    echo '---'
    echo '# spine:managed — do not edit'
    echo "description: >-"
    printf '  %s\n' "$_agent_description"
    [ -n "$_mapped_model" ] && echo "model: $_mapped_model"
    echo '---'
    echo ""
    printf '%s\n' "$body"
  } > "$tmp"

  if [ -f "$out_file" ] && [ ! -L "$out_file" ]; then
    backup_if_exists "$out_file"
  fi
  mv "$tmp" "$out_file"
}

# Patch ~/.codex/config.toml with spine-managed agent registrations.
# Strip-and-append: remove existing spine blocks, append fresh ones.
# Usage: patch_codex_config <codex-dir> <agents-source-dir>
patch_codex_config() {
  local target="$1" agents_src="$2"
  local config="$target/config.toml"

  mkdir -p "$target"
  backup_if_exists "$config"

  local tmp
  tmp=$(mktemp "$target/spine-config-tmp.XXXXXX")

  # Strip existing spine-managed blocks (from marker to next blank line)
  if [ -f "$config" ] && [ -s "$config" ]; then
    local skip=false
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$line" = "# spine:managed" ]; then
        skip=true; continue
      fi
      if $skip; then
        [ -z "$line" ] && { skip=false; continue; }
        continue
      fi
      printf '%s\n' "$line"
    done < "$config" > "$tmp"
    # Trim trailing blank lines from preserved content
    if [ -s "$tmp" ]; then
      local preserved
      preserved=$(<"$tmp")
      if [ -n "$preserved" ]; then
        printf '%s\n' "$preserved" > "$tmp"
      else
        : > "$tmp"
      fi
    fi
  fi

  # Append spine-managed agent entries
  for md in "$agents_src/"*.md; do
    [ -f "$md" ] || continue
    parse_agent_frontmatter "$md"
    [ -n "$_agent_name" ] || continue
    local desc="${_agent_description//\\/\\\\}"
    desc="${desc//\"/\\\"}"
    # Blank line separator: before each entry if file has content
    [ -s "$tmp" ] && printf '\n' >> "$tmp"
    printf '# spine:managed\n[agents.%s]\ndescription = "%s"\nconfig_file = "agents/%s.toml"\n' \
      "$_agent_name" "$desc" "$_agent_name" >> "$tmp"
  done

  if [ ! -s "$tmp" ]; then
    warn "Generated empty config.toml — leaving original unchanged"
    rm -f "$tmp"
    return 0
  fi

  mv "$tmp" "$config"
}

# --- Install skills via runtime launcher ---

SKILLS_RUNTIME_PACKAGE="skills@latest"
SKILLS_RUNTIME_CHOICES=()
SKILLS_RUNTIME_CMD=()
SKILLS_RUNTIME_DISPLAY=()

print_command() {
  local arg
  printf '    ' >&2
  for arg in "$@"; do
    printf '%q ' "$arg" >&2
  done
  printf '\n' >&2
}

set_skills_runtime_launcher() {
  SKILLS_RUNTIME_CMD=()
  SKILLS_RUNTIME_DISPLAY=()

  case "$1" in
    nlx)
      SKILLS_RUNTIME_CMD=(nlx "$SKILLS_RUNTIME_PACKAGE")
      ;;
    bunx)
      SKILLS_RUNTIME_CMD=(bunx "$SKILLS_RUNTIME_PACKAGE")
      ;;
    bun)
      SKILLS_RUNTIME_CMD=(bun x "$SKILLS_RUNTIME_PACKAGE")
      ;;
    npx)
      SKILLS_RUNTIME_CMD=(npx --yes "$SKILLS_RUNTIME_PACKAGE")
      ;;
    *)
      return 1
      ;;
  esac

  SKILLS_RUNTIME_DISPLAY=("${SKILLS_RUNTIME_CMD[@]}")
}

resolve_skills_runtime() {
  SKILLS_RUNTIME_CHOICES=()
  if command -v nlx >/dev/null 2>&1; then
    SKILLS_RUNTIME_CHOICES+=(nlx)
  fi
  if command -v bunx >/dev/null 2>&1; then
    SKILLS_RUNTIME_CHOICES+=(bunx)
  fi
  if command -v bun >/dev/null 2>&1; then
    SKILLS_RUNTIME_CHOICES+=(bun)
  fi
  if command -v npx >/dev/null 2>&1; then
    SKILLS_RUNTIME_CHOICES+=(npx)
  fi
  [ ${#SKILLS_RUNTIME_CHOICES[@]} -gt 0 ] || return 1
  set_skills_runtime_launcher "${SKILLS_RUNTIME_CHOICES[0]}"
}

run_skills_command() {
  local launcher
  for launcher in "${SKILLS_RUNTIME_CHOICES[@]}"; do
    set_skills_runtime_launcher "$launcher"
    if quiet "${SKILLS_RUNTIME_CMD[@]}" "$@"; then
      return 0
    fi
  done
  return 1
}

print_skills_commands() {
  local launcher
  for launcher in "${SKILLS_RUNTIME_CHOICES[@]}"; do
    set_skills_runtime_launcher "$launcher"
    print_command "${SKILLS_RUNTIME_DISPLAY[@]}" "$@"
  done
}

install_skills() {
  local skills_src="$1"; shift
  local detected_tools=("$@")

  # Build -a flags from detected tools, mapping to skills agent names
  local agent_flags=()
  for tool in "${detected_tools[@]}"; do
    case "$tool" in
      claude)  agent_flags+=(-a "claude-code") ;;
      qwen)    agent_flags+=(-a "qwen-code") ;;
      copilot) agent_flags+=(-a "github-copilot") ;;
      *)       agent_flags+=(-a "$tool") ;;
    esac
  done

  # Discover public skills (skills/ directory only — excludes internal claude/skills/)
  local skill_flags=()
  local current_skills=()
  local sname
  for skill_md in "$skills_src/skills/"*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    sname="$(basename "$(dirname "$skill_md")")"
    skill_flags+=(-s "$sname")
    current_skills+=("$sname")
  done

  if ! resolve_skills_runtime; then
    warn "No supported launcher found for bootstrapping $SKILLS_RUNTIME_PACKAGE"
    echo "" >&2
    echo "  Install one of these launchers, then re-run this installer:" >&2
    echo "    nlx" >&2
    echo "    bunx" >&2
    echo "    bun  # for 'bun x'" >&2
    echo "    npx" >&2
    echo "" >&2
    return 0
  fi

  local spine_manifest="$HOME/.config/spine/spine-skills.txt"
  cp "$spine_manifest" "${spine_manifest}.prev" 2>/dev/null || true

  # Spine skills: install public skills, then remove any renamed/deleted orphans
  local install_ok=0
  local lock_file="$HOME/.agents/.skill-lock.json"
  if [ ${#skill_flags[@]} -eq 0 ]; then
    warn "No public skills found in $skills_src/skills/"
  elif run_skills_command add "$skills_src" "${skill_flags[@]}" "${agent_flags[@]}" -g -y; then
    done_msg "spine: ${#current_skills[@]} public skills"
    install_ok=1
  else
    warn "Failed to install spine skills"
    print_skills_commands add "$skills_src" "${skill_flags[@]}" "${agent_flags[@]}" -g -y
  fi

  if [ "$install_ok" -eq 1 ]; then
    mkdir -p "$HOME/.config/spine"  # defensive; setup_central_dir runs first

    # Local skill orphans are detected via the manifest diff below.
    # Do NOT add local skill names to RETIRED_GLOBAL_SKILLS — that mechanism
    # is for lockfile-tracked external skills only.
    local tmp_manifest
    tmp_manifest="$(mktemp)"
    printf '%s\n' "${current_skills[@]}" > "$tmp_manifest"
    mv "$tmp_manifest" "$spine_manifest"

    if [ -f "${spine_manifest}.prev" ]; then
      local prev_skill
      while IFS= read -r prev_skill; do
        [ -z "$prev_skill" ] && continue
        [[ "$prev_skill" =~ ^[a-zA-Z0-9_-]+$ ]] || continue          # path-traversal guard
        # Condition 2: still in source?
        [ -d "$skills_src/skills/$prev_skill" ] && continue
        # Condition 3: physical dir exists?
        [ -d "$HOME/.agents/skills/$prev_skill" ] || continue
        # Condition 4: externally managed (in lockfile)? Skip.
        if [ -f "$lock_file" ] && \
           jq -e --arg s "$prev_skill" '.skills[$s]' "$lock_file" >/dev/null 2>&1; then
          info "Skipping $prev_skill — externally managed (skill-lock.json)"
          continue
        fi
        info "Removing orphaned spine skill: $prev_skill"
        # cleanup_stale_files() (step 8) sweeps broken symlinks in ~/.{claude,cursor,codex}/skills/
        # whose targets contain ".agents/skills/" — spine_targets. No change needed there.
        rm -rf "$HOME/.agents/skills/$prev_skill" || warn "Failed to remove orphan: $prev_skill"
      done < "${spine_manifest}.prev"
    fi
  fi

  # Global/external skills
  local failed=()
  for entry in "${GLOBAL_SKILLS[@]}"; do
    # entry is e.g. "obra/superpowers -s brainstorming"
    local skill_name="${entry##*-s }"
    local entry_tokens=()
    read -r -a entry_tokens <<< "$entry"
    if run_skills_command add "${entry_tokens[@]}" "${agent_flags[@]}" -g -y; then
      done_msg "global: $skill_name"
    else
      failed+=("$entry")
      warn "Failed to install global skill: $skill_name"
    fi
  done

  if [ ${#failed[@]} -gt 0 ]; then
    warn "Some global skills failed. Install manually:"
    for entry in "${failed[@]}"; do
      local entry_tokens=()
      read -r -a entry_tokens <<< "$entry"
      print_skills_commands add "${entry_tokens[@]}" "${agent_flags[@]}" -g -y
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
      run_skills_command remove "${global_orphans[@]}" "${agent_flags[@]}" -g -y || true
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
    [ "$tool" = "opencode" ] && target="$HOME/.config/opencode"
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

    # Codex: remove stale spine-managed .toml agent files
    if [ "$tool" = "codex" ] && [ -d "$target/agents" ]; then
      for toml in "$target/agents/"*.toml; do
        [ -f "$toml" ] || continue
        head -1 "$toml" | grep -q '^# spine:managed' || continue
        local agent_name
        agent_name=$(basename "$toml" .toml)
        if [ ! -f "$HOME/.config/spine/agents/$agent_name.md" ]; then
          rm "$toml"
          cleaned=$((cleaned + 1))
        fi
      done
    fi

    # Cursor/Qwen/Copilot/OpenCode: remove stale spine-managed .md agent files
    if { [ "$tool" = "cursor" ] || [ "$tool" = "qwen" ] || [ "$tool" = "copilot" ] || [ "$tool" = "opencode" ]; } && [ -d "$target/agents" ]; then
      for md in "$target/agents/"*.md; do
        [ -f "$md" ] || continue
        [ -L "$md" ] && continue  # skip symlinks
        head -3 "$md" | grep -q '^# spine:managed' || continue
        local agent_name
        agent_name=$(basename "$md" .md)
        if [ ! -f "$HOME/.config/spine/agents/$agent_name.md" ]; then
          rm "$md"
          cleaned=$((cleaned + 1))
        fi
      done
    fi
  done

  # Remove retired agent names across all providers
  if [ ${#RETIRED_AGENT_NAMES[@]} -gt 0 ]; then
    for tool in "${detected_tools[@]}"; do
      local target="$HOME/.$tool"
      [ "$tool" = "opencode" ] && target="$HOME/.config/opencode"
      for retired in "${RETIRED_AGENT_NAMES[@]}"; do
        if [ -e "$target/agents/$retired.md" ] || [ -L "$target/agents/$retired.md" ]; then
          rm "$target/agents/$retired.md"
          cleaned=$((cleaned + 1))
        fi
        if [ -f "$target/agents/$retired.toml" ] && \
           head -1 "$target/agents/$retired.toml" | grep -q '^# spine:managed'; then
          rm "$target/agents/$retired.toml"
          cleaned=$((cleaned + 1))
        fi
      done
    done
  fi

  # Remove retired skill names from ~/.agents/skills/
  if [ ${#RETIRED_SKILL_NAMES[@]} -gt 0 ]; then
    for retired in "${RETIRED_SKILL_NAMES[@]}"; do
      if [ -d "$HOME/.agents/skills/$retired" ]; then
        rm -rf "$HOME/.agents/skills/$retired"
        cleaned=$((cleaned + 1))
      fi
    done
  fi

  if [ "$cleaned" -gt 0 ]; then
    done_msg "Cleaned $cleaned stale file(s)"
  fi
}

# --- Main ---

main() {
  echo "" >&2
  info "Spine installer — AI coding setup"

  # Step 1: Resolve source
  step "1/7" "Resolving source..."
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

  # Step 2: Set up central directory
  step "2/7" "Setting up central directory..."
  setup_central_dir "$src"

  # Step 3: System dependencies
  step "3/7" "Checking system dependencies..."
  ensure_system_deps

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

  # Step 5: Install guardrails, agents, plugin, RTK, MCP — one line per tool, progressive
  step "5/7" "Configuring tools..."
  for tool in "${tools[@]}"; do
    tool_start "$tool"
    install_tool "$tool" "$src"
    _install_rtk_single "$tool"
    _install_mcp_single "$tool"
    tool_done
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
  printf "%b\n" "${_C_GREEN}✓ Spine installed for: ${tools[*]}${_C_RESET}" >&2
  echo "" >&2
}

main "$@"
