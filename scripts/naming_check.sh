#!/usr/bin/env bash
# Spec section 12 #24: the strings "Tetris" and "Block Blast" must not appear in the repo
# outside docs/SPEC.md (which states the naming rule).
set -euo pipefail
cd "$(dirname "$0")/.."
hits=$(git grep -n -I -i -E 'tetris|block[ _-]?blast' -- . ':!docs/SPEC.md' ':!scripts/naming_check.sh' ':!pubspec.lock' || true)
if [ -n "$hits" ]; then
  echo "Forbidden trademark strings found:"
  echo "$hits"
  exit 1
fi
echo "naming check OK"
