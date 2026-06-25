#!/usr/bin/env bats
# @file tests/unit/vscode-settings.bats
# @brief Regression tests for VS Code user settings.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
SETTINGS_TEMPLATE="$DOTFILES_ROOT/home/Library/Application Support/Code/User/settings.json"
PERSONAL_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'

render_settings() {
  local data="$1"

  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$data" <"$SETTINGS_TEMPLATE"
}


@test "vscode settings keep extension and schema preferences" {
  run render_settings "$PERSONAL_DATA"

  assert_success
  assert_output --partial '"extensions.ignoreRecommendations": true'
  assert_output --partial '"json.schemaDownload.trustedDomains": {'
  assert_output --partial '"https://opencode.ai": true'
  assert_output --partial '"https://json.schemastore.org/": true'
  refute_output --partial '"https://www.schemastore.org/": true'
  refute_output --partial '"https://schemastore.azurewebsites.net/": true'
}
