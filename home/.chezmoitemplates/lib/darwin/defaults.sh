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
# @description Add an app to the Dock when it exists.
#
function dock_add_app() {
  local app="$1"

  [ -d "${app}" ] || return 0
  dockutil --no-restart --add "${app}" >/dev/null
}

#
# @description Add the personal Dock app order.
#
function dock_apply_personal_layout() {
  dock_add_app "/System/Applications/Apps.app"
  dock_add_app "/System/Applications/System Settings.app"
  dock_add_app "/System/Applications/Utilities/Activity Monitor.app"
  dock_add_app "/Applications/Brave Browser.app"
  dock_add_app "${HOME}/Applications/Brave Browser Apps.localized/YouTube Music.app"
  dock_add_app "/Applications/Visual Studio Code.app"
  dock_add_app "/Applications/Ghostty.app"
  dock_add_app "/Applications/Discord.app"
  dock_add_app "/System/Applications/Mail.app"
  dock_add_app "/System/Applications/Notes.app"
  dock_add_app "/System/Applications/Reminders.app"
  dock_add_app "/Applications/superwhisper.app"
}

#
# @description Add the work Dock app order.
#
function dock_apply_work_layout() {
  dock_add_app "/System/Applications/Apps.app"
  dock_add_app "/System/Applications/System Settings.app"
  dock_add_app "/System/Applications/Utilities/Activity Monitor.app"
  dock_add_app "/Applications/Brave Browser.app"
  dock_add_app "${HOME}/Applications/Brave Browser Apps.localized/YouTube Music.app"
  dock_add_app "/Applications/Visual Studio Code.app"
  dock_add_app "/Applications/Ghostty.app"
  dock_add_app "/Applications/Microsoft Outlook.app"
  dock_add_app "/Applications/Microsoft Teams.app"
  dock_add_app "/Applications/Slack.app"
  dock_add_app "/System/Applications/Notes.app"
  dock_add_app "/System/Applications/Reminders.app"
  dock_add_app "/Applications/superwhisper.app"
}

#
# @description Add the Dock layout for the active dotfiles context.
#
function dock_apply_layout() {
  case "${DOTFILES_CONTEXT:-personal}" in
  work)
    dock_apply_work_layout
    ;;
  *)
    dock_apply_personal_layout
    ;;
  esac
}

#
# @description Configure Dock defaults and app order.
#
function dock_configure() {
  defaults write com.apple.dock orientation -string bottom
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock tilesize -int 42
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-time-modifier -float 0.5
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock show-recents -bool false

  if command -v dockutil >/dev/null 2>&1; then
    dockutil --no-restart --remove all >/dev/null 2>&1 || true
    dock_apply_layout
  else
    log_warn "[defaults] dockutil not found. Run 'brew install dockutil' or rerun 'chezmoi apply'."
  fi

  # Best-effort restart; killall exits non-zero when Dock is not running.
  killall Dock || true
}

#
# @description Apply macOS system defaults.
#
function macos_defaults_main() {
  log_info "[defaults] Applying macOS defaults..."

  # Best-effort; osascript exits non-zero if System Settings is absent or
  # automation is denied. Either way, do not abort the defaults run.
  osascript -e 'tell application "System Settings" to quit' || true

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
  # Best-effort restart; killall exits non-zero when Finder is not running.
  killall Finder || true

  dock_configure

  defaults write com.apple.screencapture disable-shadow -bool true
  mkdir -p "${HOME}/Pictures/Screenshots"
  defaults write com.apple.screencapture location -string "${HOME}/Pictures/Screenshots"
  defaults write com.apple.screencapture show-thumbnail -bool false
  # Best-effort restart; killall exits non-zero when SystemUIServer is not running.
  killall SystemUIServer || true

  defaults write com.apple.CrashReporter DialogType none
  defaults write com.apple.LaunchServices LSQuarantine -bool false
  defaults write -g AppleShowScrollBars -string Always

  if ! defaults read com.apple.LaunchServices/com.apple.launchservices.secure 2>/dev/null |
    grep -q '"LSHandlerRoleAll" = "com\.brave\.browser"'; then
    # Best-effort; open exits non-zero when Brave is not installed.
    open -a "Brave Browser" --args --make-default-browser || true
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
