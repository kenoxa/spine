#!/bin/sh
# inject-compact-essentials.sh
# SessionStart hook (matcher: "compact") — re-injects critical rules after compaction.
# Post-compaction, CLAUDE.md is re-loaded with a "may or may not be relevant" disclaimer
# that demotes rules to suggestions. This hook reinforces the highest-impact rules.

# Bail silently when running under Cursor — this is a Claude-only hook.
# Cursor parses sessionStart hook stdout as JSON; plain text causes SyntaxError.
[ "${SPINE_PROVIDER_IS_CURSOR:-}" = "1" ] && { printf '{}'; exit 0; }

cat <<'ESSENTIALS'
## Post-Compaction Essentials

- Re-read `.scratch/<session>/session-log.md` to recover session state before continuing
- Use native tools: Grep not rg/grep, Glob not find/ls, Read not cat/head/tail, Edit not sed/awk
- Evidence levels: E0 intuition, E1 doc ref, E2 code ref, E3 executed output. Blocking claims require E2+.
- Never expand scope beyond what was explicitly requested
- Subagent cap: ≤6 per dispatch. Self-contained prompts, no inherited history.
ESSENTIALS
