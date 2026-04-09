#!/bin/bash
# macOS sensible defaults
# Run: ./macos.sh (or make macos)

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Scrollbars
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Finder: show extensions, hidden files, path bar, status bar, list view
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Dock: autohide, minimize to app, no recent apps
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock show-recents -bool false

# Trackpad: tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Screenshots: save to ~/Screenshots, no shadow
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture disable-shadow -bool true
mkdir -p "$HOME/Screenshots"

# Disable auto-correct and smart quotes (interferes with code)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Restart affected apps
for app in Finder Dock SystemUIServer; do
  killall "$app" 2>/dev/null || true
done

echo "macOS defaults applied. Some changes may require a logout/restart."
