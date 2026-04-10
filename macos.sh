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

# Dock: left side, autohide, minimize to app, no recent apps, curated apps only
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock show-recents -bool false

# Remove all apps from Dock, then add only Apps (Finder & Trash are always present)
defaults write com.apple.dock persistent-apps -array \
  "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file:///System/Applications/Apps.app/</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>Apps</string><key>file-type</key><integer>41</integer></dict><key>tile-type</key><string>file-tile</string></dict>"
# Add Downloads folder
defaults write com.apple.dock persistent-others -array \
  "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://${HOME}/Downloads/</string><key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>Downloads</string><key>file-type</key><integer>2</integer><key>arrangement</key><integer>2</integer><key>displayas</key><integer>1</integer><key>showas</key><integer>0</integer></dict><key>tile-type</key><string>directory-tile</string></dict>"

# Trackpad: tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Screenshots: save to ~/Screenshots, no shadow
defaults write com.apple.screencapture location -string "$HOME/Downloads"
defaults write com.apple.screencapture disable-shadow -bool true

# Disable Spotlight keyboard shortcut (using Raycast instead)
/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:enabled bool false" ~/Library/Preferences/com.apple.symbolichotkeys.plist

# Disable auto-correct and smart quotes (interferes with code)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable Gatekeeper "app downloaded from internet" confirmation
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Default browser
if command -v defaultbrowser &>/dev/null; then
  defaultbrowser firefox
fi

# Restart affected apps
for app in Finder Dock SystemUIServer; do
  killall "$app" 2>/dev/null || true
done

echo "macOS defaults applied. Some changes may require a logout/restart."
