#!/bin/sh

set -eu

usage() {
	cat <<'EOF'
Usage:
  collect_sessions.sh --days N (--scratch PATH | --session ID) [--workspace DIR] [--scripts-dir DIR]

Options:
  --days N            Time window in days to parse.
  --scratch PATH      Scratch directory for parser output.
  --session ID        Session ID used to build .scratch path when --scratch is omitted.
  --workspace DIR     Workspace root containing .scratch/. Default: current directory.
  --scripts-dir DIR   Parser script directory. Default: this script's directory.
  -h, --help          Show this help text.
EOF
}

error() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

shell_quote() {
	printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

script_dir() {
	(
		CDPATH=
		export CDPATH
		cd -- "$(dirname -- "$1")" && pwd
	)
}

compute_since() {
	days="$1"

	if date -v-"$days"d +%Y-%m-%d >/dev/null 2>&1; then
		date -v-"$days"d +%Y-%m-%d
		return 0
	fi

	if date -d "$days days ago" +%Y-%m-%d >/dev/null 2>&1; then
		date -d "$days days ago" +%Y-%m-%d
		return 0
	fi

	return 1
}

DAYS=""
SCRATCH=""
SCRIPTS_DIR="$(script_dir "$0")"
SESSION=""
WORKSPACE="$(pwd)"

while [ $# -gt 0 ]; do
	case "$1" in
	--days)
		[ $# -ge 2 ] || error "missing value for --days"
		DAYS="$2"
		shift 2
		;;
	--scratch)
		[ $# -ge 2 ] || error "missing value for --scratch"
		SCRATCH="$2"
		shift 2
		;;
	--session)
		[ $# -ge 2 ] || error "missing value for --session"
		SESSION="$2"
		shift 2
		;;
	--workspace)
		[ $# -ge 2 ] || error "missing value for --workspace"
		WORKSPACE="$2"
		shift 2
		;;
	--scripts-dir)
		[ $# -ge 2 ] || error "missing value for --scripts-dir"
		SCRIPTS_DIR="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		error "unknown argument: $1"
		;;
	esac
done

[ -n "$DAYS" ] || error "--days is required"
case "$DAYS" in
'' | *[!0-9]*)
	error "--days must be a non-negative integer"
	;;
esac

if [ -z "$SCRATCH" ]; then
	[ -n "$SESSION" ] || error "provide --scratch or --session"
	SCRATCH="$WORKSPACE/.scratch/$SESSION"
fi

PYTHON=$(command -v python3 || command -v python || true)
[ -n "$PYTHON" ] || error "Python 3.9+ required but not found"

if ! "$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
	error "Python 3.9+ required but found incompatible version"
fi

SINCE=$(compute_since "$DAYS") || error "unable to compute date range for --days=$DAYS"

for script_name in parse_claude.py parse_codex.py parse_cursor.py aggregate.py; do
	[ -f "$SCRIPTS_DIR/$script_name" ] || error "missing parser script: $SCRIPTS_DIR/$script_name"
done

mkdir -p "$SCRATCH"
{
	printf 'SINCE=%s\n' "$(shell_quote "$SINCE")"
	printf 'SCRATCH=%s\n' "$(shell_quote "$SCRATCH")"
	printf 'SCRIPTS_DIR=%s\n' "$(shell_quote "$SCRIPTS_DIR")"
	printf 'WORKSPACE=%s\n' "$(shell_quote "$WORKSPACE")"
} >"$SCRATCH/collect.env"

PYTHONPATH="$SCRIPTS_DIR" "$PYTHON" "$SCRIPTS_DIR/parse_claude.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS_DIR" "$PYTHON" "$SCRIPTS_DIR/parse_codex.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS_DIR" "$PYTHON" "$SCRIPTS_DIR/parse_cursor.py" --since "$SINCE" --output "$SCRATCH"
PYTHONPATH="$SCRIPTS_DIR" "$PYTHON" "$SCRIPTS_DIR/aggregate.py" --input "$SCRATCH" --output "$SCRATCH/analytics.json"
