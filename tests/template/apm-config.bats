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
  assert_line '    - name: grep'
  assert_line '      registry: false'
  assert_line '      url: https://mcp.grep.app'
  refute_line --regexp '^\s*- name: figma$'
  refute_line --regexp '^\s*- name: atlassian-jira$'
  refute_line --regexp '^\s*- name: atlassian-knowledge$'
  refute_line --regexp '\$\{FIGMA_TOKEN\}'
  refute_line --regexp '\$\{ATLASSIAN_JIRA_RESOURCE_URL\}'
  refute_line --regexp '\$\{ATLASSIAN_KNOWLEDGE_RESOURCE_URL\}'
}

@test "personal APM config renders shared and personal APM packages" {
  run render_apm_template "$PERSONAL_DATA"

  assert_success
  assert_line '    - obra/superpowers'
  assert_line '    - JuliusBrussee/caveman'
  assert_line '    - anthropics/claude-plugins-official/plugins/skill-creator'
  assert_line '    - schpet/linear-cli'
}

@test "work APM config renders Figma and both Atlassian MCP servers" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_line '    - name: grep'
  assert_line '    - name: figma'
  assert_line '      url: https://mcp.figma.com/mcp'
  assert_line '      headers:'
  assert_line '        Authorization: "Bearer ${FIGMA_TOKEN}"'
  assert_line '    - name: atlassian-jira'
  assert_line '    - name: atlassian-knowledge'
  assert_line '      command: npx'
  assert_line '      args:'
  assert_line '        - "-y"'
  assert_line '        - "${ATLASSIAN_JIRA_RESOURCE_URL}"'
  assert_line '        - "${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}"'
  refute_line --regexp '\$\{input:figma-token\}'
}

@test "work APM config renders shared APM packages without personal Linear CLI" {
  run render_apm_template "$WORK_DATA"

  assert_success
  assert_line '    - obra/superpowers'
  assert_line '    - JuliusBrussee/caveman'
  assert_line '    - anthropics/claude-plugins-official/plugins/skill-creator'
  refute_line '    - schpet/linear-cli'
}

@test "work APM config does not require legacy atlassian_resource_url data" {
  run render_apm_template "$WORK_DATA"

  assert_success
  refute_output --partial 'atlassian_resource_url'
}
