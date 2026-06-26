#!/usr/bin/env bats
# @file tests/template/apm-config.bats
# @brief Template rendering tests for home/dot_apm/apm.yml.tmpl.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

APM_TEMPLATE="$DOTFILES_ROOT/home/dot_apm/apm.yml.tmpl"

@test "personal APM config renders only shared MCP servers" {
  run render_chezmoi_template "$APM_TEMPLATE" "$PERSONAL_DATA"

  assert_success
  assert_line '    - name: "grep"'
  assert_line '      registry: false'
  assert_line '      url: "https://mcp.grep.app"'
  refute_line --regexp 'name: figma'
  refute_line --regexp 'name: jira'
}

@test "personal APM config renders personal target" {
  run render_chezmoi_template "$APM_TEMPLATE" "$PERSONAL_DATA"

  assert_success
  assert_line '  - claude'
  assert_line '  - agent-skills'
  refute_line '  - copilot'
  refute_line '  - opencode'
  refute_line '  -agent-skills:'
}

@test "personal APM config renders shared and personal APM packages" {
  run render_chezmoi_template "$APM_TEMPLATE" "$PERSONAL_DATA"

  assert_success
  assert_line --partial '    - "obra/superpowers'
  assert_line --partial '    - "JuliusBrussee/caveman'
  assert_line --partial '    - "anthropics/claude-plugins-official/plugins/skill-creator'
  assert_line --partial '    - "schpet/linear-cli'
  assert_line --partial '    - "tavily-ai/skills'
  assert_line --partial '    - git: JuliusBrussee/skills'
  assert_line '      skills:'
  assert_line '        - "grill-me"'
  assert_line '        - "junior-to-senior"'
  refute_line --partial 'interface-kit'
  refute_line --partial 'loop-factory'
  refute_line --partial 'context-canary'
}

@test "work APM config renders Figma and Jira MCP servers" {
  run render_chezmoi_template "$APM_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_line '    - name: "grep"'
  assert_line '    - name: "figma"'
  assert_line '      url: "https://mcp.figma.com/mcp"'
  assert_line '    - name: "jira"'
  assert_line '      url: "https://mcp.atlassian.com/v1/mcp"'
}

@test "work APM config renders work target" {
  run render_chezmoi_template "$APM_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_line '  - copilot'
  refute_line '  - opencode'
  refute_line '  - claude'
  refute_line '  - agent-skills'
  refute_line '  -copilot:'
}

@test "work APM config renders shared APM packages without personal packages" {
  run render_chezmoi_template "$APM_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_line --partial '    - "obra/superpowers'
  assert_line --partial '    - "JuliusBrussee/caveman'
  assert_line --partial '    - "anthropics/claude-plugins-official/plugins/skill-creator'
  refute_line --partial '    - schpet/linear-cli'
  refute_line --partial '    - tavily-ai/skills'
  refute_line --partial 'JuliusBrussee/skills'
  refute_line --partial 'grill-me'
  refute_line --partial 'junior-to-senior'
}
