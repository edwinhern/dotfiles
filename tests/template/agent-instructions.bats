#!/usr/bin/env bats
# @file tests/template/agent-instructions.bats
# @brief Template rendering tests for shared agent instruction markdown.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
CLAUDE_TEMPLATE="$DOTFILES_ROOT/home/dot_claude/CLAUDE.md.tmpl"
OPENCODE_TEMPLATE="$DOTFILES_ROOT/home/dot_config/opencode/AGENTS.md.tmpl"

@test "agent instruction templates render shared markdown" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" <"$CLAUDE_TEMPLATE"

  assert_success
  assert_output --partial '# Claude Code Settings'
  assert_output --partial 'Use `gh` CLI for all GitHub interactions.'

  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" <"$OPENCODE_TEMPLATE"

  assert_success
  assert_output --partial '# Claude Code Settings'
  assert_output --partial 'Use `gh` CLI for all GitHub interactions.'
}

@test "agent instruction templates use markdown template source" {
  [ -f "$DOTFILES_ROOT/home/.chezmoitemplates/AGENTS.md" ]
  [ ! -e "$DOTFILES_ROOT/home/.chezmoidata/agents.yaml" ]

  claude_template="$(<"$CLAUDE_TEMPLATE")"
  opencode_template="$(<"$OPENCODE_TEMPLATE")"

  [[ "$claude_template" == *'{{ template "AGENTS.md" . -}}'* ]]
  [[ "$opencode_template" == *'{{ template "AGENTS.md" . -}}'* ]]
}

@test "agent instruction templates render Graphify guidance" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" <"$CLAUDE_TEMPLATE"

  assert_success
  assert_output --partial '## Graphify'
  assert_output --partial 'Use the installed Graphify skill when the user invokes `/graphify`.'
  assert_output --partial 'graphify query'
  assert_output --partial 'GRAPH_REPORT.md'

  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" <"$OPENCODE_TEMPLATE"

  assert_success
  assert_output --partial '## Graphify'
  assert_output --partial 'Use the installed Graphify skill when the user invokes `/graphify`.'
  assert_output --partial 'graphify query'
  assert_output --partial 'GRAPH_REPORT.md'
}
