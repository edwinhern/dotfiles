#!/usr/bin/env bats
# @file tests/unit/claude-settings.bats
# @brief Regression tests for home/dot_claude/settings.json.

load '../test_helpers/load.bash'

SETTINGS="$DOTFILES_ROOT/home/dot_claude/settings.json"

@test "claude settings pin the model alias" {
  settings_content="$(<"$SETTINGS")"

  [[ "$settings_content" == *'"model": "best"'* ]]
}

@test "claude settings keep destructive bash commands gated" {
  settings_content="$(<"$SETTINGS")"

  [[ "$settings_content" == *'"Bash(rm:*)"'* ]]
  [[ "$settings_content" == *'"Bash(kill:*)"'* ]]
  [[ "$settings_content" == *'"Bash(rm -rf:*)"'* ]]
  [[ "$settings_content" == *'"Bash(gh release delete:*)"'* ]]
}
