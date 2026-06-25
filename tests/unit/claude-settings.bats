#!/usr/bin/env bats
# @file tests/unit/claude-settings.bats
# @brief Regression tests for home/dot_claude/settings.json.

load '../test_helpers/load.bash'

SETTINGS="$DOTFILES_ROOT/home/dot_claude/settings.json"

@test "claude settings use current model aliases" {
  settings_content="$(<"$SETTINGS")"

  [[ "$settings_content" == *'"model": "opusplan"'* ]]
  [[ "$settings_content" == *'"CLAUDE_CODE_SUBAGENT_MODEL": "inherit"'* ]]
  [[ "$settings_content" != *'ANTHROPIC_DEFAULT_OPUS_MODEL'* ]]
  [[ "$settings_content" != *'ANTHROPIC_DEFAULT_SONNET_MODEL'* ]]
  [[ "$settings_content" != *'ANTHROPIC_DEFAULT_HAIKU_MODEL'* ]]
}

@test "claude settings keep destructive bash commands gated" {
  settings_content="$(<"$SETTINGS")"

  [[ "$settings_content" == *'"Bash(rm:*)"'* ]]
  [[ "$settings_content" == *'"Bash(kill:*)"'* ]]
  [[ "$settings_content" == *'"Bash(rm -rf:*)"'* ]]
  [[ "$settings_content" == *'"Bash(gh release delete:*)"'* ]]
}
