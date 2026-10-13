#!/usr/bin/env bats
# @file tests/template/agent-instructions.bats
# @brief Template rendering tests for shared agent instruction markdown.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

CLAUDE_TEMPLATE="$DOTFILES_ROOT/home/dot_claude/CLAUDE.md.tmpl"

@test "agent instruction templates render shared markdown" {
  run render_chezmoi_template "$CLAUDE_TEMPLATE"

  assert_success
  assert_line --index 0 '# Agent Guidance'
  assert_line --regexp '^## GitHub CLI$'
  assert_line 'Use `gh` CLI for all GitHub interactions. Never clone repositories to read code.'
  refute_line '## Graphify'
}
