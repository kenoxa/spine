#!/bin/sh
# _project.sh — find project root from a file path.
# Walks up from the given path looking for package.json or .git.
#
# Usage: _project.sh <file-path>
# Outputs: project root path on stdout
# Exit: 0 if found, 1 if not (reached /)
#
# spine:managed — do not edit

if [ $# -eq 0 ] || [ ! -e "$1" ]; then
  exit 1
fi

dir=$(dirname "$1")
while [ "$dir" != "/" ]; do
  if [ -f "$dir/package.json" ] || [ -d "$dir/.git" ]; then
    echo "$dir"
    exit 0
  fi
  dir=$(dirname "$dir")
done

exit 1
