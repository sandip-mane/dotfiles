#!/bin/bash
# Installs casks/*.rb into a local tap so Brewfile can reference pinned versions
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP="sandip-mane/local"

brew tap | grep -qx "$TAP" || brew tap-new --no-git "$TAP" >/dev/null
CASK_DIR="$(brew --repository "$TAP")/Casks"
mkdir -p "$CASK_DIR"
cp "$DOTFILES"/casks/*.rb "$CASK_DIR/"
