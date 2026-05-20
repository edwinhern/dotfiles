#!/usr/bin/env bash
# @file lib/darwin/defaults.sh
# @brief Apply macOS defaults.
# @description
#   Applies Finder, Dock, screenshot, and browser defaults for macOS. This file
#   is sourceable from bats tests and injected into chezmoi run scripts via
#   chezmoi template rendering.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

#
# @description Apply macOS system defaults.
#
function macos_defaults_main() {
  log_info "[defaults] Applying macOS defaults..."

  osascript -e 'tell application "System Settings" to quit'

  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
  defaults write com.apple.finder ShowSidebar -bool true
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowTabView -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write com.apple.finder CreateDesktop -bool false
  killall Finder

  defaults write com.apple.dock orientation -string bottom
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock tilesize -int 42
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-time-modifier -float 0.5
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock show-recents -bool false

  # TODO: We should make a function that focuses on setting this dotfiles because one is going to be for work and one is going to be for personal, meaning that some apps are going to be added that are personal and some are going to be added that are work. And in a sense, I kind of want to append it based on like if conditions. If it's a personal, we're going to add these apps. It's work, we're going to add these apps and we should consider to add them in specific areas. for, yeah.
  if command -v dockutil >/dev/null 2>&1; then
    dockutil --no-restart --remove all >/dev/null 2>&1 || true
    for app in \
      "/System/Applications/Apps.app" \
      "/System/Applications/System Settings.app" \
      "/System/Applications/Utilities/Activity Monitor.app" \
      "/Applications/Google Chrome.app" \
      "/Applications/Visual Studio Code.app" \
      "/Applications/Ghostty.app" \
      "/Applications/Discord.app" \
      "/System/Applications/Music.app" \
      "/System/Applications/Mail.app" \
      "/System/Applications/Notes.app" \
      "/System/Applications/Reminders.app" \
      "/Applications/superwhisper.app"; do
      [ -d "${app}" ] && dockutil --no-restart --add "${app}" >/dev/null
    done
  else
    log_warn "[defaults] dockutil not found. Run 'brew install dockutil' or rerun 'chezmoi apply'."
  fi
  killall Dock

  defaults write com.apple.screencapture disable-shadow -bool true
  mkdir -p "${HOME}/Pictures/Screenshots"
  defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"
  defaults write com.apple.screencapture show-thumbnail -bool false
  killall SystemUIServer

  defaults write com.apple.CrashReporter DialogType none
  defaults write com.apple.LaunchServices LSQuarantine -bool false
  defaults write -g AppleShowScrollBars -string Always

  if ! defaults read com.apple.LaunchServices/com.apple.launchservices.secure 2>/dev/null |
    grep -q '"LSHandlerRoleAll" = "com\.google\.chrome"'; then
    open -a "Google Chrome" --args --make-default-browser
  fi

  log_info "[defaults] macOS defaults applied."
}

#
# @description Run the macOS defaults flow.
#
function main() {
  macos_defaults_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
