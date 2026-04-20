#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/Work/dotfiles"
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

# Re-stow all packages
echo "Re-stowing packages..."
for pkg in packages/*/; do
  stow -d packages -t "$HOME" --no-folding -R "$(basename "$pkg")"
done

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

if compgen -G "$DOTFILES/configs/iterm2/*.json" > /dev/null; then
  ITERM_DYN_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$ITERM_DYN_DIR"
  for f in "$DOTFILES"/configs/iterm2/*.json; do
    ln -sfn "$f" "$ITERM_DYN_DIR/$(basename "$f")"
  done
  if [ -f "$DOTFILES/configs/iterm2/Default.json" ]; then
    DEFAULT_GUID=$(python3 -c "import json; print(json.load(open('$DOTFILES/configs/iterm2/Default.json'))['Profiles'][0]['Guid'])")
    defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$DEFAULT_GUID"
  fi
fi

echo "Dotfiles synced."
