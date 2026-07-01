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
}

@test "agent instruction templates use markdown template source" {
  [ -f "$DOTFILES_ROOT/home/.chezmoitemplates/AGENTS.md" ]
  [ ! -e "$DOTFILES_ROOT/home/.chezmoidata/agents.yaml" ]

  claude_template="$(<"$CLAUDE_TEMPLATE")"

  [[ "$claude_template" == *'{{ template "AGENTS.md" . -}}'* ]]
}

@test "agent instruction templates render Graphify guidance" {
  run render_chezmoi_template "$CLAUDE_TEMPLATE"

  assert_success
  assert_line '## Graphify'
  assert_line '- Use the installed Graphify skill when the user invokes `/graphify`.'
  assert_line --partial 'graphify query'
  assert_line --partial 'GRAPH_REPORT.md'
}
