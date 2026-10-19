#!/usr/bin/env bash
# Install packs into a project (.claude/) or globally (~/.claude).
# Usage: ./install.sh [--global] [pack-number ...]    e.g. ./install.sh 1 2   (default: all packs)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dest=".claude"
if [ "${1:-}" = "--global" ]; then dest="$HOME/.claude"; shift; fi

packs=("$@")
if [ ${#packs[@]} -eq 0 ]; then packs=(1 2 3 4 5 6); fi

for n in "${packs[@]}"; do
  pack=$(ls -d "$here"/packs/"$n"-* 2>/dev/null | head -1 || true)
  if [ -z "$pack" ]; then echo "Pack $n not found" >&2; exit 1; fi
  for kind in skills agents; do
    [ -d "$pack/$kind" ] || continue
    mkdir -p "$dest/$kind"
    cp -R "$pack/$kind/." "$dest/$kind/"
  done
  echo "Installed $(basename "$pack") -> $dest"
done
