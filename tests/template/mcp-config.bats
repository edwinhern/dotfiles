#!/usr/bin/env bats
# @file tests/template/mcp-config.bats
# @brief Render tests for the VS Code MCP config template.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

VSCODE_MCP="$DOTFILES_ROOT/home/Library/Application Support/Code/User/mcp.json.tmpl"

@test "VS Code MCP config renders an empty server map when no servers" {
  run render_chezmoi_template "$VSCODE_MCP" "$DARWIN_DATA"
  assert_success
  assert_line --partial '"servers": {}'
}

@test "VS Code MCP config renders servers when configured" {
  local data='{"chezmoi":{"os":"darwin"},"ai":{"mcp":[{"name":"test-server","transport":"http","url":"https://example.com/mcp"}]}}'
  run render_chezmoi_template "$VSCODE_MCP" "$data"
  assert_success
  assert_line --partial '"servers"'
  assert_line --partial '"test-server"'
  assert_line --partial 'https://example.com/mcp'
}
