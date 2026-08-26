#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

# Pull latest changes
if [ "${SKIP_PULL:-}" != "1" ]; then
  echo "Pulling latest changes..."
  git pull --rebase --autostash
fi

# Update Homebrew and install new items (skip Gatekeeper quarantine on casks)
echo "Updating Homebrew packages..."
export HOMEBREW_CASK_OPTS="--no-quarantine"
brew update
brew bundle --file="$DOTFILES/Brewfile"
brew cleanup

# --no-quarantine above is only honored on fresh cask installs, not upgrades,
# so updated apps get re-quarantined. Strip the top-level attr (the one
# Gatekeeper checks) so it stops prompting. Needs App Management permission
# for this terminal, which Homebrew cask installs already require.
for app in /Applications/*.app; do
  xattr -d com.apple.quarantine "$app" 2>/dev/null || true
done

# Re-stow all packages
echo "Re-stowing packages..."
for pkg in packages/*/; do
  stow -d packages -t "$HOME" --no-folding -R "$(basename "$pkg")"
done

echo "Generating Claude settings..."
"$DOTFILES/claude-settings.sh"

# Update oh-my-zsh plugins and theme
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
echo "Updating oh-my-zsh plugins..."
for dir in \
  "$ZSH_CUSTOM/themes/powerlevel10k" \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"; do
  [ -d "$dir" ] && git -C "$dir" pull --quiet 2>/dev/null || true
done

# Apply macOS and app defaults
echo "Applying defaults..."
source "$DOTFILES/macos.sh"
source "$DOTFILES/configs/calendr/defaults.sh"
source "$DOTFILES/configs/maccy/defaults.sh"
mkdir -p "$HOME/Library/Application Support/com.nuebling.mac-mouse-fix"
cp "$DOTFILES/configs/mac-mouse-fix/config.plist" "$HOME/Library/Application Support/com.nuebling.mac-mouse-fix/config.plist"

# cmux: settings + shortcuts in cmux.json, terminal rendering in Ghostty config
if [ -d "$DOTFILES/configs/cmux" ]; then
  mkdir -p "$HOME/.config/cmux" "$HOME/.config/ghostty"
  ln -sfn "$DOTFILES/configs/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"
  ln -sfn "$DOTFILES/configs/cmux/ghostty.conf" "$HOME/.config/ghostty/config"
fi

echo "Dotfiles synced."
