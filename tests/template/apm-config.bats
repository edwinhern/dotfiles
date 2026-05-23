#!/usr/bin/env bats
# @file tests/template/apm-config.bats
# @brief Template rendering tests for home/dot_apm/apm.yml.tmpl.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
APM_TEMPLATE="$DOTFILES_ROOT/home/dot_apm/apm.yml.tmpl"
PERSONAL_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'

render_apm_template() {
  local data="$1"

  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$data" <"$APM_TEMPLATE"
}

@test "personal APM config renders only shared MCP servers" {
  run render_apm_template "$PERSONAL_DATA"

  assert_success
  assert_output --partial '    - name: grep'
  assert_output --partial '      registry: false'
  assert_output --partial '      url: https://mcp.grep.app'
  refute_output --partial 'name: figma'
  refute_output --partial 'name: atlassian-jira'
  refute_output --partial 'name: atlassian-knowledge'
  refute_output --partial '${FIGMA_TOKEN}'
  refute_output --partial '${ATLASSIAN_JIRA_RESOURCE_URL}'
  refute_output --partial '${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}'
}

@test "personal APM config renders shared and personal APM packages" {
  run render_apm_template "$PERSONAL_DATA"

  assert_success
  assert_output --partial '    - obra/superpowers'
  assert_output --partial '    - JuliusBrussee/caveman'
  assert_output --partial '    - anthropics/claude-plugins-official/plugins/skill-creator'
  assert_output --partial '    - schpet/linear-cli'
}

@test "work APM config renders Figma and both Atlassian MCP servers" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_output --partial '    - name: grep'
  assert_output --partial '    - name: figma'
  assert_output --partial '      url: https://mcp.figma.com/mcp'
  assert_output --partial '      headers:'
  assert_output --partial '        Authorization: "Bearer ${FIGMA_TOKEN}"'
  assert_output --partial '    - name: atlassian-jira'
  assert_output --partial '    - name: atlassian-knowledge'
  assert_output --partial '      command: npx'
  assert_output --partial '      args:'
  assert_output --partial '        - "-y"'
  assert_output --partial '"${ATLASSIAN_JIRA_RESOURCE_URL}"'
  assert_output --partial '"${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}"'
  refute_output --partial '${input:figma-token}'
}

@test "work APM config renders shared APM packages without personal Linear CLI" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_output --partial '    - obra/superpowers'
  assert_output --partial '    - JuliusBrussee/caveman'
  assert_output --partial '    - anthropics/claude-plugins-official/plugins/skill-creator'
  refute_output --partial '    - schpet/linear-cli'
}

@test "work APM config does not require legacy atlassian_resource_url data" {
  run render_apm_template "$WORK_DATA"

  assert_success
  refute_output --partial 'atlassian_resource_url'
}
