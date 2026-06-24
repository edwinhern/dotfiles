#!/usr/bin/env bats
# @file tests/unit/opencode-config.bats
# @brief Regression tests for home/dot_config/opencode/opencode.jsonc.

load '../test_helpers/load.bash'

CONFIG="$DOTFILES_ROOT/home/dot_config/opencode/opencode.jsonc"

@test "opencode config avoids stale OpenAI model tuning" {
  config_content="$(<"$CONFIG")"

  [[ "$config_content" == *'"model": "openai/gpt-5.5"'* ]]
  [[ "$config_content" != *'"small_model"'* ]]
  [[ "$config_content" != *'"provider"'* ]]
  [[ "$config_content" != *'"reasoningEffort"'* ]]
  [[ "$config_content" != *'"textVerbosity"'* ]]
  [[ "$config_content" != *'"reasoningSummary"'* ]]
}

@test "opencode config does not include supermemory plugin" {
  config_content="$(<"$CONFIG")"

  [[ "$config_content" != *'opencode-supermemory'* ]]
  [[ "$config_content" == *'"opencode-wakatime"'* ]]
}

@test "opencode config omits Tavily MCP" {
  config_content="$(<"$CONFIG")"

  [[ "$config_content" == *'"grep": {'* ]]
  [[ "$config_content" != *'"tavily": {'* ]]
  [[ "$config_content" != *'TAVILY_API_KEY'* ]]
}
