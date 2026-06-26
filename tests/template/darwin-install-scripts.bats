#!/usr/bin/env bats
# @file tests/template/darwin-install-scripts.bats
# @brief Template rendering tests for Darwin chezmoi install scripts.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

EMPTY_APM_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false,"apm":{"targets":{"shared":[],"personal":[],"work":[]}}}'
PACKAGE_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl"
UV_TOOLS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-uv-tools.sh.tmpl"
GRAPHIFY_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl"

@test "darwin install script templates render with bash shebang" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    run render_chezmoi_template "$template" "$DARWIN_DATA"
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

@test "darwin install script templates inject Graphify shell library" {
  assert_file_contains "$GRAPHIFY_TEMPLATE" '{{ template "lib/install/graphify-skills.sh" . }}'
}

@test "rendered darwin install scripts are syntactically valid bash" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    rendered="$(render_chezmoi_template "$template" "$DARWIN_DATA")"
    printf '%s\n' "$rendered" | bash -n
  done
}

@test "personal package template keeps personal tools and omits work apps" {
  run render_chezmoi_template "$PACKAGE_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'brew "mas"'
  assert_line 'brew "mise"'
  assert_line 'cask "discord"'
  assert_line 'mas "Klack", id: 6446206067'
  refute_line 'cask "microsoft-office"'
  refute_line 'cask "microsoft-teams"'
  refute_line 'cask "slack"'
  refute_line --partial 'Be Focused - Pomodoro Timer'
}

@test "work package template renders approved work apps" {
  run render_chezmoi_template "$PACKAGE_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_line 'brew "mas"'
  assert_line 'cask "microsoft-office"'
  assert_line 'cask "microsoft-teams"'
  assert_line 'cask "slack"'
  assert_line 'mas "Be Focused - Pomodoro Timer", id: 973134470'
  refute_line 'cask "discord"'
  refute_line 'mas "Klack", id: 6446206067'
  refute_line 'cask "microsoft-outlook"'
  refute_line 'brew "java"'
  refute_line 'brew "gradle"'
  refute_line 'brew "maven"'
  refute_line 'brew "kafka"'
}

@test "personal uv tools template renders Graphify and Tavily CLI tools" {
  run render_chezmoi_template "$UV_TOOLS_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'UV_TOOLS=('
  assert_line --partial '"graphifyy"'
  assert_line --partial '"tavily-cli"'
  assert_line --partial 'uv_tools_install_main'
}

@test "work uv tools template has no personal uv tools" {
  run render_chezmoi_template "$UV_TOOLS_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_line --partial '"graphifyy"'
  refute_line --partial '"tavily-cli"'
  refute_line --partial 'uv tool install --upgrade'
  refute_line --partial 'uv_tools_install_main'
}

@test "personal Graphify template renders agent and Claude platforms" {
  run render_chezmoi_template "$GRAPHIFY_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'GRAPHIFY_PLATFORMS=('
  assert_line --partial '"agents"'
  assert_line --partial '"claude"'
  assert_line --partial 'graphify_skills_install_main'
}

@test "work Graphify template renders no personal platforms" {
  run render_chezmoi_template "$GRAPHIFY_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_line --partial '"agents"'
  refute_line --partial '"claude"'
  refute_line --partial 'graphify install --platform'
  refute_line --partial 'graphify_skills_install_main'
}

@test "empty APM target groups render no Graphify commands" {
  run render_chezmoi_template "$GRAPHIFY_TEMPLATE" "$EMPTY_APM_DATA"

  assert_success
  refute_line 'GRAPHIFY_PLATFORMS=('
  refute_line --partial 'graphify install --platform'
  refute_line --partial 'graphify_skills_install_main'
}
