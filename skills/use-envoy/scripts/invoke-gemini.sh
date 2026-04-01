#!/bin/sh
# Invoke Gemini models via Copilot CLI for cross-provider envoy.
# Gemini is a pseudo-provider: routes through Copilot CLI to access
# Google Gemini models (Gemini 3.1 Pro, Gemini 3 Flash).
# Privacy: GitHub data handling (Business/Enterprise: no training, IP indemnity).
# Exit codes: same as invoke-copilot.sh

set -eu

_script_dir=$(cd "$(dirname "$0")" && pwd)

# shellcheck source=_common.sh
. "$_script_dir/_common.sh"

# --- Extract tier from args ---
_tier="standard"
_prev=""
for _arg in "$@"; do
    case "$_prev" in --tier) _tier="$_arg"; break ;; esac
    _prev="$_arg"
done

# --- Resolve Gemini model for tier ---
resolve_tier "$_tier" gemini
# shellcheck disable=SC2154  # set by resolve_tier
_model="$_tier_model"

# --- Env override cascade: SPINE_ENVOY_{TIER}_GEMINI > SPINE_ENVOY_GEMINI > resolved ---
_tier_upper=$(printf '%s' "$_tier" | tr '[:lower:]' '[:upper:]')
eval "_env_tier=\${SPINE_ENVOY_${_tier_upper}_GEMINI:-}" || _env_tier=""
_env_base="${SPINE_ENVOY_GEMINI:-}"

if [ -n "$_env_tier" ]; then
    _model="$_env_tier"
elif [ -n "$_env_base" ]; then
    _model="$_env_base"
fi

# --- Delegate to Copilot CLI with Gemini model ---
# Use tier-specific copilot override to prevent user's base SPINE_ENVOY_COPILOT
# from shadowing the Gemini model. Tier-specific takes highest precedence in
# invoke-copilot.sh's cascade (lines 80-84).
# Append empty effort via trailing colon — Copilot has no effort for Gemini models.
exec env "SPINE_ENVOY_${_tier_upper}_COPILOT=${_model}:" \
    sh "$_script_dir/invoke-copilot.sh" "$@"
