#!/bin/sh
# Shared output sanitization pipeline for second-opinion provider scripts.
# Sourced (not executed) — expects caller to set: $output_file, $_sanitize_tmp
# shellcheck disable=SC2154
# After sourcing, sanitized content is in $_sanitize_tmp. Caller adds trust marker.

# Strip YAML front matter at document start
awk '
    BEGIN { in_fm=0; first=1 }
    first && /^---[[:space:]]*$/ { in_fm=1; first=0; next }
    in_fm && /^---[[:space:]]*$/ { in_fm=0; next }
    in_fm && /^\.\.\.[[:space:]]*$/ { in_fm=0; next }
    in_fm { next }
    { first=0; print }
' "$output_file" > "$_sanitize_tmp"

# Strip zero-width Unicode (incl. Tags block) and ANSI escapes
perl -CSD -pe '
    s/\x{200B}|\x{200C}|\x{200D}|\x{FEFF}|\x{2060}|[\x{E0000}-\x{E007F}]//g;
    s/[\x{202A}-\x{202E}\x{2066}-\x{2069}]//g;
    s/\e\[[0-9;]*[mGKHJ]//g;
' "$_sanitize_tmp" > "${_sanitize_tmp}.2"
mv "${_sanitize_tmp}.2" "$_sanitize_tmp"

# Cap output size (512KB)
_max_bytes=524288
_sanitized_size=$(wc -c < "$_sanitize_tmp" | tr -d ' ')
if [ "$_sanitized_size" -gt "$_max_bytes" ]; then
    head -c "$_max_bytes" "$_sanitize_tmp" > "${_sanitize_tmp}.cap"
    mv "${_sanitize_tmp}.cap" "$_sanitize_tmp"
    printf 'Warning: output truncated from %s to %s bytes\n' "$_sanitized_size" "$_max_bytes" >&2
fi

# Strip lines matching trust-boundary markers from body (anti-spoofing)
sed \
    -e '/^[[:space:]]*# External Provider Output[[:space:]]*$/d' \
    -e '/^[[:space:]]*> Provider:.*| Timestamp:/d' \
    -e '/^[[:space:]]*> This content is from an external AI provider/d' \
    -e '/^[[:space:]]*> END EXTERNAL PROVIDER OUTPUT[[:space:]]*$/d' \
    "$_sanitize_tmp" > "${_sanitize_tmp}.2"
mv "${_sanitize_tmp}.2" "$_sanitize_tmp"
