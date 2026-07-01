#!/usr/bin/env bats
# @file tests/template/mcp-config.bats
# @brief Render tests for the Copilot MCP config templates.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

COPILOT_MCP="$DOTFILES_ROOT/home/dot_copilot/mcp-config.json.tmpl"
VSCODE_MCP="$DOTFILES_ROOT/home/Library/Application Support/Code/User/mcp.json.tmpl"

# WORK_DATA and PERSONAL_DATA come from templates.bash; the real ai.yaml supplies
# .ai (targets and mcp) because chezmoi merges --override-data over .chezmoidata.
# A work machine targets github-copilot and gets shared + work MCP servers; a
# personal machine has no github-copilot target, so the maps render empty.

@test "work Copilot CLI MCP config renders shared and work servers" {
  run render_chezmoi_template "$COPILOT_MCP" "$WORK_DATA"
  assert_success
  assert_line --partial '"mcpServers"'
  assert_line --partial '"grep"'
  assert_line --partial '"figma"'
  assert_line --partial '"jira"'
  assert_line --partial 'https://mcp.figma.com/mcp'
  assert_line --partial '"tools"'
}

@test "personal Copilot CLI MCP config renders an empty server map" {
  run render_chezmoi_template "$COPILOT_MCP" "$PERSONAL_DATA"
  assert_success
  assert_line --partial '"mcpServers": {}'
}

@test "work VS Code MCP config renders shared and work servers" {
  run render_chezmoi_template "$VSCODE_MCP" "$WORK_DATA"
  assert_success
  assert_line --partial '"servers"'
  assert_line --partial '"grep"'
  assert_line --partial '"jira"'
  assert_line --partial 'https://mcp.atlassian.com/v1/mcp'
}

@test "personal VS Code MCP config renders an empty server map" {
  run render_chezmoi_template "$VSCODE_MCP" "$PERSONAL_DATA"
  assert_success
  assert_line --partial '"servers": {}'
}
