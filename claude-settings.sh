#!/bin/bash
set -euo pipefail

# Generates ~/.claude/settings.json from the tracked base. Claude Code rewrites
# this file at runtime, so it cannot be a stow symlink.

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE="$DOTFILES/configs/claude/settings.base.json"
TARGET="$HOME/.claude/settings.json"

# Keys Claude Code owns at runtime; carried over instead of being regenerated.
# autoMode describes the machine's trust boundary and stays out of this public repo.
PRESERVE='{autoMode}'

[ -f "$BASE" ] || { echo "No base Claude settings at $BASE" >&2; exit 1; }

TMPDIR_="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_"' EXIT

mkdir -p "$HOME/.claude"

# Older setups stowed this file; a symlink would write back into the repo.
if [ -L "$TARGET" ]; then rm "$TARGET"; fi

if [ -f "$TARGET" ]; then
  LIVE="$TARGET"
else
  LIVE="$TMPDIR_/empty.json"
  echo '{}' > "$LIVE"
fi

OUT="$TMPDIR_/settings.json"
jq -s '.[0] * (.[1] | '"$PRESERVE"' | with_entries(select(.value != null)))' "$BASE" "$LIVE" > "$OUT"

if [ -f "$TARGET" ] && cmp -s "$OUT" "$TARGET"; then
  exit 0
fi

cp "$OUT" "$TARGET"
chmod 600 "$TARGET"
