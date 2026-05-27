#!/usr/bin/env bats
# @file tests/unit/lib/darwin/defaults.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/darwin/defaults.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/darwin/defaults.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export COMMAND_LOG="$BATS_TEST_TMPDIR/commands"
  export DOCK_APPS_LOG="$BATS_TEST_TMPDIR/dock-apps"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"

  for command_name in defaults osascript killall dockutil open; do
    cat >"$BATS_TEST_TMPDIR/bin/$command_name" <<'COMMAND'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$COMMAND_LOG"
if [[ "$(basename "$0")" == defaults && "${1:-}" == read ]]; then
  exit 1
fi
COMMAND
    chmod +x "$BATS_TEST_TMPDIR/bin/$command_name"
  done

  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

capture_dock_layout() {
  local context="$1"
  bash -c "
    source '$LOG_LIB'
    source '$LIB'
    dock_add_app() { printf '%s\n' \"\$1\" >>'$DOCK_APPS_LOG'; }
    DOTFILES_CONTEXT='$context' dock_apply_layout
  "
}

@test "macos_defaults_main: applies defaults and restarts affected services" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && macos_defaults_main"

  assert_success
  assert_output --partial "[defaults] Applying macOS defaults..."
  assert_output --partial "[defaults] macOS defaults applied."
  assert_file_contains "$COMMAND_LOG" "defaults write NSGlobalDomain AppleShowAllExtensions -bool true"
  assert_file_contains "$COMMAND_LOG" "killall Finder"
  assert_file_contains "$COMMAND_LOG" "dockutil --no-restart --remove all"
  assert_file_contains "$COMMAND_LOG" "open -a Brave Browser --args --make-default-browser"
}

@test "dock_apply_layout: personal layout uses personal communication apps" {
  run capture_dock_layout personal

  assert_success
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Discord.app"
  assert_file_contains "$DOCK_APPS_LOG" "/System/Applications/Mail.app"
  assert_file_contains "$DOCK_APPS_LOG" "$HOME/Applications/Brave Browser Apps.localized/YouTube Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/System/Applications/Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Outlook.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Teams.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Slack.app"
}

@test "dock_apply_layout: work layout uses work communication apps" {
  run capture_dock_layout work

  assert_success
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Outlook.app"
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Teams.app"
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Slack.app"
  assert_file_contains "$DOCK_APPS_LOG" "$HOME/Applications/Brave Browser Apps.localized/YouTube Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Discord.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/System/Applications/Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/System/Applications/Mail.app"
}
