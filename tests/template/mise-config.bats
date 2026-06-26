#!/usr/bin/env bats
# @file tests/template/mise-config.bats
# @brief Template rendering tests for home/dot_config/mise/config.toml.tmpl.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

MISE_TEMPLATE="$DOTFILES_ROOT/home/dot_config/mise/config.toml.tmpl"

@test "mise config installs APM for personal hosts" {
  run render_chezmoi_template "$MISE_TEMPLATE" "$PERSONAL_DATA"

  assert_success
  assert_line '"github:microsoft/apm" = "latest"'
}

@test "mise config renders tools from mise data groups" {
  [ -f "$DOTFILES_ROOT/home/.chezmoidata/mise.yaml" ]

  template_content="$(<"$MISE_TEMPLATE")"

  [[ "$template_content" == *'$.mise.tools'* ]]
}

@test "mise config installs Linear CLI for personal hosts" {
  run render_chezmoi_template "$MISE_TEMPLATE" "$PERSONAL_DATA"

  assert_success
  assert_line '"npm:@schpet/linear-cli" = "latest"'
}

@test "mise config installs uv for personal hosts" {
  run render_chezmoi_template "$MISE_TEMPLATE" "$PERSONAL_DATA"

  assert_success
  assert_line '"uv" = "latest"'
}

@test "mise config installs APM for work hosts" {
  run render_chezmoi_template "$MISE_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_line '"github:microsoft/apm" = "latest"'
}

@test "mise config does not install Linear CLI for work hosts" {
  run render_chezmoi_template "$MISE_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_line '"npm:@schpet/linear-cli" = "latest"'
}

@test "mise config does not install uv for work hosts" {
  run render_chezmoi_template "$MISE_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_line '"uv" = "latest"'
}
