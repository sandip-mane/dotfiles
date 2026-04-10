#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/Work/dotfiles"

echo "Starting Mac bootstrap..."

# 1. Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Press enter after Xcode CLI tools installation completes."
  read -r
fi

# 2. Homebrew
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# 3. Clone dotfiles repo
if [ ! -d "$DOTFILES" ]; then
  echo "Cloning dotfiles..."
  git clone https://github.com/sandip-mane/dotfiles.git "$DOTFILES"
else
  echo "Dotfiles repo exists, pulling latest..."
  git -C "$DOTFILES" pull --rebase --autostash
fi

# 4. Brew bundle
echo "Installing Homebrew packages..."
brew bundle --file="$DOTFILES/Brewfile"

# 5. VS Code settings
if command -v code &>/dev/null && [ -f "$DOTFILES/vscode/sandip.code-profile" ]; then
  echo "Applying VS Code settings..."
  PROFILE_JSON=$(cat "$DOTFILES/vscode/sandip.code-profile")
  VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

  # Find target: existing profile dir or base User dir
  VSCODE_ACTIVE_PROFILE=$(ls "$VSCODE_USER_DIR/profiles" 2>/dev/null | head -1 || true)
  if [ -n "$VSCODE_ACTIVE_PROFILE" ]; then
    VSCODE_TARGET="$VSCODE_USER_DIR/profiles/$VSCODE_ACTIVE_PROFILE"
  else
    VSCODE_TARGET="$VSCODE_USER_DIR"
  fi
  mkdir -p "$VSCODE_TARGET"

  # Extract settings and keybindings from profile and write as files
  echo "$PROFILE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.loads(d['settings']) if isinstance(d['settings'],str) else d['settings'])" > /dev/null 2>&1 && \
  echo "$PROFILE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(json.loads(d['settings']),indent=4))" > "$VSCODE_TARGET/settings.json" && \
  echo "$PROFILE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(json.loads(d['keybindings']),indent=4))" > "$VSCODE_TARGET/keybindings.json"

  # Install extensions from profile
  echo "$PROFILE_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for ext in json.loads(d['extensions']):
    print(ext['identifier']['id'])
" | xargs -L 1 code --install-extension 2>/dev/null || true
fi

# 6. Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 7. Oh My Zsh plugins and theme
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  echo "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# 8. Backup existing dotfiles and stow
echo "Stowing dotfiles..."
for f in .zshrc .p10k.zsh .gitconfig .vimrc .wezterm.lua; do
  if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
    echo "  Backing up ~/$f"
    mv "$HOME/$f" "$HOME/$f.backup.$(date +%s)"
  fi
done

# Backup nested configs
for f in .ssh/config .config/mise/config.toml .config/gh/config.yml .config/atuin/config.toml .docker/config.json; do
  if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
    echo "  Backing up ~/$f"
    mv "$HOME/$f" "$HOME/$f.backup.$(date +%s)"
  fi
done

cd "$DOTFILES"
for pkg in packages/*/; do
  stow -d packages -t "$HOME" -R "$(basename "$pkg")"
done

# 9. Install mise runtimes
if command -v mise &>/dev/null; then
  echo "Installing mise runtimes..."
  eval "$(mise activate bash)"
  mise install --yes
fi

# 10. macOS defaults
echo "Applying macOS defaults..."
source "$DOTFILES/macos.sh"

# 11. Set default shell to Homebrew zsh
BREW_ZSH="/opt/homebrew/bin/zsh"
if [ -x "$BREW_ZSH" ]; then
  if ! grep -q "$BREW_ZSH" /etc/shells; then
    echo "Adding Homebrew zsh to /etc/shells (requires sudo)..."
    echo "$BREW_ZSH" | sudo tee -a /etc/shells
  fi
  if [ "$SHELL" != "$BREW_ZSH" ]; then
    echo "Setting default shell to Homebrew zsh..."
    chsh -s "$BREW_ZSH"
  fi
fi

# 12. Import Raycast config
if [ -f "$DOTFILES/raycast/config.rayconfig" ]; then
  echo "Opening Raycast for config import..."
  open -a "Raycast"
  sleep 3
  echo "Importing Raycast config — use password: 12345678"
  open "$DOTFILES/raycast/config.rayconfig"
fi

# 13. Add login items
echo "Adding login items..."
for app in "Docker" "Calendr" "1Password" "Maccy" "Lunar" "Magnet"; do
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$app.app\", hidden:false}" 2>/dev/null || true
done

echo ""
echo "Bootstrap complete! Restart your terminal to apply all changes."
echo ""
echo "Manual steps:"
echo "  - Install NeetoRecord: https://neetorecord.com/neetorecord/download"
echo "  - Grant Accessibility permissions for: Magnet, Maccy, Raycast, Lunar"
