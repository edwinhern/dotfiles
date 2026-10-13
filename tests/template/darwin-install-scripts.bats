#!/usr/bin/env bats
# @file tests/template/darwin-install-scripts.bats
# @brief Template rendering tests for Darwin chezmoi install scripts.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

EMPTY_AI_DATA='{"chezmoi":{"os":"darwin"},"ai":{"targets":[],"skills":[],"plugins":[],"mcp":[]}}'
PACKAGE_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl"
UV_TOOLS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-uv-tools.sh.tmpl"
AI_SKILLS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_07_install-ai-skills.sh.tmpl"
AI_PLUGINS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_06_install-ai-plugins.sh.tmpl"
AI_MCP_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_08_install-ai-mcp.sh.tmpl"

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

@test "darwin install script templates inject the install prelude" {
  local prelude='{{ template "lib/common/install-prelude.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_once_01_install-homebrew.sh.tmpl" "$prelude"
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl" "$prelude"
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-mise-tools.sh.tmpl" "$prelude"
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-uv-tools.sh.tmpl" "$prelude"
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_04_install-vscode-extensions.sh.tmpl" "$prelude"
  assert_file_contains "$AI_SKILLS_TEMPLATE" "$prelude"
  assert_file_contains "$AI_PLUGINS_TEMPLATE" "$prelude"
}

@test "rendered darwin install scripts are syntactically valid bash" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    rendered="$(render_chezmoi_template "$template" "$DARWIN_DATA")"
    printf '%s\n' "$rendered" | bash -n
  done
}

@test "package template renders homebrew formulas, casks, and mas apps" {
  run render_chezmoi_template "$PACKAGE_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'brew "mas"'
  assert_line 'brew "mise"'
  assert_line 'cask "discord"'
  assert_line 'cask "claude-code"'
  assert_line 'mas "Klack", id: 6446206067'
  refute_line 'cask "copilot-cli"'
  refute_line 'cask "microsoft-office"'
  refute_line 'cask "microsoft-teams"'
  refute_line 'cask "slack"'
  refute_line --partial 'Be Focused - Pomodoro Timer'
}

@test "package template renders heredoc delimiter on its own line" {
  run render_chezmoi_template "$PACKAGE_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line "HOMEBREW_BUNDLE_CONTENT=\$(cat <<'BREWFILE'"
  refute_line --regexp "^HOMEBREW_BUNDLE_CONTENT=\\\$\\(cat <<'BREWFILE'.+"
}

@test "uv tools template renders configured tools" {
  run render_chezmoi_template "$UV_TOOLS_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'UV_TOOLS=('
  assert_line --partial '"tavily-cli"'
  refute_line --partial '"graphifyy"'
  assert_line --partial 'uv_tools_install_main'
}

@test "AI skills template targets claude-code with skills" {
  run render_chezmoi_template "$AI_SKILLS_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'AI_SKILL_TARGETS=('
  assert_line --partial '"claude-code"'
  refute_line --partial '"github-copilot"'
  assert_line --partial 'export AI_LOCAL_SKILLS_DIR='
  assert_line --partial '.chezmoitemplates/skills'
  assert_line --partial '"blader/humanizer|humanizer"'
  assert_line --partial '"local|testing"'
  assert_line --partial '"juliusbrussee/skills|interface-kit"'
  assert_line --partial '"upstash/context7|context7-cli"'
  assert_line --partial 'ai_skills_install_main'
}

@test "empty AI target groups render no AI skills commands" {
  run render_chezmoi_template "$AI_SKILLS_TEMPLATE" "$EMPTY_AI_DATA"

  assert_success
  refute_line 'AI_SKILL_TARGETS=('
  refute_line --partial 'ai_skills_install_main'
}

@test "AI plugins template targets claude-code and includes plugins" {
  run render_chezmoi_template "$AI_PLUGINS_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_line 'AI_PLUGIN_TARGETS=('
  assert_line --partial '"claude-code"'
  refute_line --partial '"github-copilot"'
  assert_line --partial '"caveman|caveman|JuliusBrussee/caveman|"'
  assert_line --partial '"superpowers|superpowers-dev|obra/superpowers|"'
  assert_line --partial 'ai_plugins_install_main'
}

@test "empty AI target groups render no AI plugins commands" {
  run render_chezmoi_template "$AI_PLUGINS_TEMPLATE" "$EMPTY_AI_DATA"

  assert_success
  refute_line 'AI_PLUGIN_TARGETS=('
  refute_line --partial 'ai_plugins_install_main'
}

@test "darwin install script templates inject the prelude before AI MCP" {
  local prelude
  prelude='{{ template "lib/common/install-prelude.sh" . }}'
  assert_file_contains "$AI_MCP_TEMPLATE" "$prelude"
}

@test "AI MCP template renders no servers when MCP list is empty" {
  run render_chezmoi_template "$AI_MCP_TEMPLATE" "$DARWIN_DATA"
  assert_success
  refute_line --partial 'lib/install/ai-mcp.sh'
}

@test "empty AI target groups render no AI MCP commands" {
  run render_chezmoi_template "$AI_MCP_TEMPLATE" "$EMPTY_AI_DATA"
  assert_success
  refute_line --partial 'lib/install/ai-mcp.sh'
}
