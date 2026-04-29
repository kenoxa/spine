#!/bin/sh
# anonymize-advisors.sh — strip lens identity from council advisor outputs and assign A–E labels
# Usage: scripts/anonymize-advisors.sh <session-dir>
set -eu

if [ $# -ne 1 ]; then
  echo "Usage: $0 <session-dir>" >&2
  exit 1
fi

SESSION_DIR="$1"

if [ ! -d "$SESSION_DIR" ]; then
  echo "Error: session directory not found: $SESSION_DIR" >&2
  exit 1
fi

SLUGS="contrarian first-principles expansionist outsider executor"

# Verify all 5 input files exist before doing anything
for slug in $SLUGS; do
  file="$SESSION_DIR/council-advisor-${slug}.md"
  if [ ! -f "$file" ]; then
    echo "Error: missing batch output — expected $file" >&2
    echo "Run Phase 2 (Batch) before Phase 3 (Peer Review)." >&2
    exit 1
  fi
done

# Shuffle A–E using openssl rand for a cryptographically random sort key per letter
shuffled=$(for letter in A B C D E; do
  printf '%s %s\n' "$(openssl rand -hex 4)" "$letter"
done | sort | awk '{print $2}')

i=1
json='{'
sep=''
for slug in $SLUGS; do
  letter=$(printf '%s\n' "$shuffled" | awk "NR==$i")
  src="$SESSION_DIR/council-advisor-${slug}.md"
  dst="$SESSION_DIR/council-advisor-anon-${letter}.md"

  # Strip YAML frontmatter, skip leading blank lines, replace first H1, redact lens identity
  awk -v letter="$letter" '
    BEGIN { in_front=0; h1_done=0 }
    NR==1 && /^---[[:space:]]*$/ { in_front=1; next }
    in_front && /^---[[:space:]]*$/ { in_front=0; next }
    in_front { next }
    !h1_done && /^[[:space:]]*$/ { next }
    !h1_done && /^#[[:space:]]/ { print "# Advisor " letter; h1_done=1; next }
    # Metadata lines: strip full value — the description after the colon identifies the lens
    { gsub(/\*\*Lens\*\*:.*/, "**Lens**: [REDACTED]") }
    { gsub(/\*\*Stance\*\*:.*/, "**Stance**: [REDACTED]") }
    # Lens file path references
    { gsub(/council-lens-[a-z-]+\.md/, "council-lens-[redacted].md") }
    # Lens names — capitalized and lowercase, including hyphenated first-principles
    { gsub(/[Cc]ontrarian/, "[LENS]") }
    { gsub(/[Ff]irst.[Pp]rinciples/, "[LENS]") }
    { gsub(/[Ee]xpansionist/, "[LENS]") }
    { gsub(/[Oo]utsider/, "[LENS]") }
    { gsub(/[Ee]xecutor/, "[LENS]") }
    { print }
  ' "$src" > "$dst"

  json="${json}${sep}\"${letter}\": \"${slug}\""
  sep=', '

  printf 'Assigned %s → Advisor %s (%s)\n' "$slug" "$letter" "$dst"
  i=$((i + 1))
done

json="${json}}"

map_file="$SESSION_DIR/council-anon-map.json"
printf '%s\n' "$json" > "$map_file"

printf '\nAnonymization complete.\n'
printf 'Mapping written to %s\n' "$map_file"
printf 'Anonymous outputs: %s/council-advisor-anon-{A,B,C,D,E}.md\n' "$SESSION_DIR"
