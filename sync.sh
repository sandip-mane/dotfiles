#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/Work/dotfiles"
cd "$DOTFILES"

# Pull latest changes
if [ "${SKIP_PULL:-}" != "1" ]; then
  echo "Pulling latest changes..."
  git pull --rebase --autostash
fi

# Update Homebrew and install new items
echo "Updating Homebrew packages..."
brew update
brew bundle --file="$DOTFILES/Brewfile"
brew cleanup

# VS Code extensions
if command -v code &>/dev/null && [ -f "$DOTFILES/vscode/extensions.txt" ]; then
  echo "Syncing VS Code extensions..."
  xargs -L 1 code --install-extension < "$DOTFILES/vscode/extensions.txt" || true
fi

# Re-stow all packages
echo "Re-stowing packages..."
for pkg in packages/*/; do
  stow -d packages -t "$HOME" -R "$(basename "$pkg")"
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

# Apply macOS defaults
echo "Applying macOS defaults..."
source "$DOTFILES/macos.sh"

echo "Dotfiles synced."
