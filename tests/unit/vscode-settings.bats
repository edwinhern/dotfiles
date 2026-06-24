#!/usr/bin/env bats
# @file tests/unit/vscode-settings.bats
# @brief Regression tests for VS Code user settings.

load '../test_helpers/load.bash'

SETTINGS="$DOTFILES_ROOT/home/Library/Application Support/Code/User/settings.json"

@test "vscode settings disable unwanted AI integrations" {
  assert_file_contains "$SETTINGS" '"chat.disableAIFeatures": true'
  assert_file_contains "$SETTINGS" '"gitlens.gitkraken.mcp.autoEnabled": false'
}

@test "vscode settings keep extension and schema preferences" {
  assert_file_contains "$SETTINGS" '"extensions.ignoreRecommendations": true'
  assert_file_contains "$SETTINGS" '"json.schemaDownload.trustedDomains": {'
  assert_file_contains "$SETTINGS" '"https://opencode.ai": true'
  assert_file_contains "$SETTINGS" '"https://json.schemastore.org/": true'
}
