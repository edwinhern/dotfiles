#!/usr/bin/env bats
# @file tests/template/darwin-install-scripts.bats
# @brief Template rendering tests for Darwin chezmoi install scripts.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
DARWIN_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'
PACKAGE_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl"
UV_TOOLS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-uv-tools.sh.tmpl"
GRAPHIFY_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl"
EMPTY_APM_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false,"apm":{"targets":{"shared":[],"personal":[],"work":[]}}}'

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
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-uv-tools.sh.tmpl" '{{ template "lib/install/uv-tools.sh" . }}'
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
  assert_output --partial 'mas "Klack", id: 6446206067'
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
  refute_output --partial 'cask "discord"'
  refute_output --partial 'mas "Klack", id: 6446206067'
  refute_output --partial 'cask "microsoft-outlook"'
  refute_output --partial 'brew "java"'
  refute_output --partial 'brew "gradle"'
  refute_output --partial 'brew "maven"'
  refute_output --partial 'brew "kafka"'
}

@test "personal uv tools template renders Graphify and Tavily CLI tools" {
  run render_template_with_data "$UV_TOOLS_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_output --partial 'UV_TOOLS=('
  assert_output --partial '"graphifyy"'
  assert_output --partial '"tavily-cli"'
  assert_output --partial 'uv_tools_install_main'
}

@test "work uv tools template has no personal uv tools" {
  run render_template_with_data "$UV_TOOLS_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_output --partial '"graphifyy"'
  refute_output --partial '"tavily-cli"'
  refute_output --partial 'uv tool install --upgrade'
  refute_output --partial 'uv_tools_install_main'
}

@test "darwin install script templates inject Graphify shell library" {
  assert_file_contains "$GRAPHIFY_TEMPLATE" '{{ template "lib/install/graphify-skills.sh" . }}'
}

@test "personal Graphify template renders agent and Claude platforms" {
  run render_template_with_data "$GRAPHIFY_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_output --partial 'GRAPHIFY_PLATFORMS=('
  assert_output --partial '"agents"'
  assert_output --partial '"claude"'
  assert_output --partial 'graphify_skills_install_main'
}

@test "work Graphify template renders no personal platforms" {
  run render_template_with_data "$GRAPHIFY_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_output --partial '"agents"'
  refute_output --partial '"claude"'
  refute_output --partial 'graphify install --platform'
  refute_output --partial 'graphify_skills_install_main'
}

@test "empty APM target groups render no Graphify commands" {
  run render_template_with_data "$GRAPHIFY_TEMPLATE" "$EMPTY_APM_DATA"

  assert_success
  refute_output --partial 'GRAPHIFY_PLATFORMS=('
  refute_output --partial 'graphify install --platform'
  refute_output --partial 'graphify_skills_install_main'
}
