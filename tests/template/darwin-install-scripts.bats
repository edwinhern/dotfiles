#!/usr/bin/env bats
# @file tests/template/darwin-install-scripts.bats
# @brief Template rendering tests for Darwin chezmoi install scripts.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
DARWIN_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'
PACKAGE_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl"

render_template() {
  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$1"
}

render_template_with_data() {
  local template="$1"
  local data="$2"

  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$data" <"$template"
}

@test "darwin install script templates render with bash shebang" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    run render_template "$template"
    assert_success
    [ "${lines[0]}" = "#!/usr/bin/env bash" ]
  done
}

@test "darwin install script templates inject shell libraries" {
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl" '{{ template "lib/install/homebrew-bundle.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-mise-tools.sh.tmpl" '{{ template "lib/install/mise.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_04_install-vscode-extensions.sh.tmpl" '{{ template "lib/install/vscode.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_05_defaults.sh.tmpl" '{{ template "lib/darwin/defaults.sh" . }}'
}

@test "rendered darwin install scripts are syntactically valid bash" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    rendered="$(render_template "$template")"
    printf '%s\n' "$rendered" | bash -n
  done
}

@test "personal package template keeps personal tools and omits work apps" {
  run render_template_with_data "$PACKAGE_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_output --partial 'brew "mas"'
  assert_output --partial 'brew "mise"'
  assert_output --partial 'cask "discord"'
  refute_output --partial 'cask "microsoft-office"'
  refute_output --partial 'cask "microsoft-teams"'
  refute_output --partial 'cask "slack"'
  refute_output --partial 'Be Focused - Pomodoro Timer'
}

@test "work package template renders approved work apps" {
  run render_template_with_data "$PACKAGE_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_output --partial 'brew "mas"'
  assert_output --partial 'cask "microsoft-office"'
  assert_output --partial 'cask "microsoft-teams"'
  assert_output --partial 'cask "slack"'
  assert_output --partial 'mas "Be Focused - Pomodoro Timer", id: 973134470'
  refute_output --partial 'cask "microsoft-outlook"'
  refute_output --partial 'brew "java"'
  refute_output --partial 'brew "gradle"'
  refute_output --partial 'brew "maven"'
  refute_output --partial 'brew "kafka"'
}
