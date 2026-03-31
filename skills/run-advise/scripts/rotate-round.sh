#!/usr/bin/env sh
# Rotate current advise round outputs into an archived subdirectory.
#
# Usage: rotate-round.sh <session-dir>

set -eu

session_dir="${1:?Usage: rotate-round.sh <session-dir>}"

# Idempotency: nothing to rotate if synthesis doesn't exist
[ -f "${session_dir}/advise-synthesis.md" ] || exit 0

# Compute round number from existing advise-r*/ directories
round=0
for d in "${session_dir}"/advise-r*/; do
	[ -d "$d" ] && round=$((round + 1))
done
round=$((round + 1))

archive="${session_dir}/advise-r${round}"
mkdir "${archive}"

# Move canonical outputs
mv "${session_dir}"/advise-batch-*.md "${archive}/"
mv "${session_dir}/advise-synthesis.md" "${archive}/"

# Move sidecars (may not exist)
for ext in log prompt; do
	for f in "${session_dir}"/advise-batch-*."${ext}"; do
		[ -e "$f" ] && mv "$f" "${archive}/"
	done
done

echo "${archive}"
