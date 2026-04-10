#!/bin/bash
# Maccy preferences

defaults write org.p0deje.Maccy pasteByDefault -bool true
defaults write org.p0deje.Maccy removeFormattingByDefault -bool true
defaults write org.p0deje.Maccy showFooter -bool true
defaults write org.p0deje.Maccy showRecentCopyInMenuBar -bool false
defaults write org.p0deje.Maccy showSearch -bool true
defaults write org.p0deje.Maccy showTitle -bool true
defaults write org.p0deje.Maccy popupPosition -string "statusItem"
defaults write org.p0deje.Maccy windowSize -string "[450,800]"
defaults write org.p0deje.Maccy "KeyboardShortcuts_popup" -string '{"carbonKeyCode":9,"carbonModifiers":768}'
defaults write org.p0deje.Maccy "KeyboardShortcuts_pin" -string '{"carbonKeyCode":35,"carbonModifiers":2048}'
defaults write org.p0deje.Maccy "KeyboardShortcuts_delete" -string '{"carbonKeyCode":51,"carbonModifiers":2048}'
