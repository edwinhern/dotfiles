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
  refute_output --partial 'name: jira'
  refute_output --partial 'name: atlassian-knowledge'
  refute_output --partial '${FIGMA_TOKEN}'
  refute_output --partial '${ATLASSIAN_JIRA_RESOURCE_URL}'
  refute_output --partial '${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}'
}

@test "personal APM config renders personal target" {
  run render_apm_template "$PERSONAL_DATA"

  assert_success
  assert_output --partial '  - claude'
  assert_output --partial '  - agent-skills'
  refute_output --partial '  - copilot'
  refute_output --partial '  - opencode'
  refute_output --partial '  -agent-skills:'
}

@test "personal APM config renders shared and personal APM packages" {
  run render_apm_template "$PERSONAL_DATA"

  assert_success
  assert_output --partial '    - obra/superpowers'
  assert_output --partial '    - JuliusBrussee/caveman'
  assert_output --partial '    - anthropics/claude-plugins-official/plugins/skill-creator'
  assert_output --partial '    - schpet/linear-cli'
  assert_output --partial '    - tavily-ai/skills'
  assert_output --partial '    - git: JuliusBrussee/skills'
  assert_output --partial '      skills:'
  assert_output --partial '        - grill-me'
  assert_output --partial '        - junior-to-senior'
  refute_output --partial 'interface-kit'
  refute_output --partial 'loop-factory'
  refute_output --partial 'context-canary'
}

@test "work APM config renders Figma and Jira MCP servers" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_output --partial '    - name: grep'
  assert_output --partial '    - name: figma'
  assert_output --partial '      url: https://mcp.figma.com/mcp'
  assert_output --partial '    - name: jira'
  assert_output --partial '      url: https://mcp.atlassian.com/v1/mcp'
  refute_output --partial 'name: atlassian-knowledge'
  refute_output --partial '${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}'
  refute_output --partial 'Authorization: "Bearer ${FIGMA_TOKEN}"'
  refute_output --partial '${input:figma-token}'
}

@test "work APM config renders work target" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_output --partial '  - copilot'
  refute_output --partial '  - opencode'
  refute_output --partial '  - claude'
  refute_output --partial '  - agent-skills'
  refute_output --partial '  -copilot:'
}

@test "work APM config renders shared APM packages without personal packages" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_output --partial '    - obra/superpowers'
  assert_output --partial '    - JuliusBrussee/caveman'
  assert_output --partial '    - anthropics/claude-plugins-official/plugins/skill-creator'
  refute_output --partial '    - schpet/linear-cli'
  refute_output --partial '    - tavily-ai/skills'
  refute_output --partial 'JuliusBrussee/skills'
  refute_output --partial 'grill-me'
  refute_output --partial 'junior-to-senior'
}

@test "work APM config does not require legacy atlassian_resource_url data" {
  run render_apm_template "$WORK_DATA"

  assert_success
  refute_output --partial 'atlassian_resource_url'
}
