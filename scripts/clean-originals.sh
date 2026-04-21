#!/usr/bin/env bash
#
# umbrella clean-originals — remove *.original.md sidecars under skills/.
#
# Caveman compression writes FILE.original.md next to every compressed file
# as a human-readable backup. These sidecars should never ship in the built
# skills/ output. build.sh cleans them at the end of a normal run, but use
# this helper after an interrupted build or when compressing files ad-hoc.
#
# Usage:
#   ./scripts/clean-originals.sh           # cleans skills/ (default)
#   ./scripts/clean-originals.sh <path>    # cleans a specific dir
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TARGET="${1:-skills}"

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target dir not found: $TARGET" >&2
  exit 1
fi

count=0
while IFS= read -r -d '' f; do
  echo "  · $f"
  rm -f "$f"
  count=$((count + 1))
done < <(find "$TARGET" -type f -name '*.original.md' -print0)

echo "✓ Removed $count .original.md file(s) from $TARGET"
