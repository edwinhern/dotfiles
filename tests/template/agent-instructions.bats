#!/usr/bin/env bats
# @file tests/template/agent-instructions.bats
# @brief The Claude instructions template renders.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

@test "Claude instructions template renders" {
  run render_chezmoi_template "$DOTFILES_ROOT/home/dot_claude/CLAUDE.md.tmpl"

  assert_success
}
