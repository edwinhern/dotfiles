# Graphify Global Agent Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Graphify global agent skills on personal machines from the existing APM target data.

**Architecture:** Add reusable chezmoi helper templates that expose active grouped data as JSON. Use those helpers in a new Darwin run-on-change script that maps personal APM targets to Graphify platforms and calls Graphify's user-scope installer. Keep per-repo graph creation, hooks, and MCP setup outside this global script.

**Tech Stack:** chezmoi templates, Bash, bats, Graphify CLI, APM target data.

---

## File Map

- Create `home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl`: renders active groups as JSON.
- Create `home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl`: renders values from active `shared`, `personal`, or `work` groups as JSON.
- Create `home/.chezmoitemplates/lib/install/graphify-skills.sh`: installs Graphify skills for `GRAPHIFY_PLATFORMS`.
- Create `home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl`: Darwin chezmoi script that maps APM targets to Graphify platforms.
- Modify `home/.chezmoitemplates/AGENTS.md`: add global Graphify usage guidance.
- Modify `tests/template/darwin-install-scripts.bats`: cover Graphify template rendering.
- Modify `tests/template/agent-instructions.bats`: cover shared Graphify instructions.
- Create `tests/unit/lib/install/graphify-skills.bats`: unit-test the Graphify installer library.

No commit steps are included because this session should not commit unless the user asks.

### Task 1: Chezmoi Group Helpers

**Files:**

- Create: `home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl`
- Create: `home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl`

- [ ] **Step 1: Add the active group helper**

Create `home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl`:

```gotemplate
{{- $groups := list "shared" -}}
{{- if .personal }}{{ $groups = append $groups "personal" }}{{ end -}}
{{- if .work }}{{ $groups = append $groups "work" }}{{ end -}}
{{- $groups | toJson -}}
```

- [ ] **Step 2: Add the active group values helper**

Create `home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl`:

```gotemplate
{{- $ctx := .ctx -}}
{{- $valuesByGroup := .valuesByGroup -}}
{{- $groups := includeTemplate "lib/chezmoi/active-groups.json.tmpl" $ctx | fromJson -}}
{{- $values := list -}}
{{- range $groups -}}
{{- $groupValues := index $valuesByGroup . -}}
{{- range $groupValues -}}
{{- $values = append $values . -}}
{{- end -}}
{{- end -}}
{{- $values | toJson -}}
```

- [ ] **Step 3: Render-check helper use through the Graphify template task**

Do not add separate helper tests yet. The Graphify template tests in Task 3 will validate the helper behavior through the real caller.

### Task 2: Graphify Installer Library

**Files:**

- Create: `tests/unit/lib/install/graphify-skills.bats`
- Create: `home/.chezmoitemplates/lib/install/graphify-skills.sh`

- [ ] **Step 1: Write the failing unit tests**

Create `tests/unit/lib/install/graphify-skills.bats`:

```bash
#!/usr/bin/env bats
# @file tests/unit/lib/install/graphify-skills.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/graphify-skills.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/graphify-skills.sh"

setup() {
  export GRAPHIFY_ARGS_FILE="$BATS_TEST_TMPDIR/graphify-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/graphify" <<'GRAPHIFY'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GRAPHIFY_ARGS_FILE"
exit "${GRAPHIFY_EXIT_CODE:-0}"
GRAPHIFY
  chmod +x "$BATS_TEST_TMPDIR/bin/graphify"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "main: installs each Graphify platform" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && GRAPHIFY_PLATFORMS=('agents' 'claude') && main"

  assert_success
  assert_output --partial "[graphify] Installing Graphify agent skills..."
  assert_output --partial "[graphify] Graphify agent skills installed."
  [ "$(<"$GRAPHIFY_ARGS_FILE")" = $'install --platform agents\ninstall --platform claude' ]
}

@test "main: skips empty platform entries" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && GRAPHIFY_PLATFORMS=('agents' '' 'claude') && main"

  assert_success
  [ "$(<"$GRAPHIFY_ARGS_FILE")" = $'install --platform agents\ninstall --platform claude' ]
}

@test "main: exits cleanly with no Graphify platforms" {
  rm -f "$BATS_TEST_TMPDIR/bin/graphify"

  run bash -c "source '$LOG_LIB' && source '$LIB' && GRAPHIFY_PLATFORMS=() && main"

  assert_success
  assert_output --partial "[graphify] No Graphify platforms to install."
  [ ! -s "$GRAPHIFY_ARGS_FILE" ]
}

@test "main: fails when graphify is missing" {
  rm -f "$BATS_TEST_TMPDIR/bin/graphify"

  run bash -c "source '$LOG_LIB' && source '$LIB' && GRAPHIFY_PLATFORMS=('agents') && main"

  assert_failure 1
  assert_output --partial "error: [graphify] graphify not found. Ensure run_onchange_03_install-uv-tools ran successfully."
}
```

- [ ] **Step 2: Run the failing unit tests**

Run: `mise exec -- bats tests/unit/lib/install/graphify-skills.bats`

Expected: FAIL because `home/.chezmoitemplates/lib/install/graphify-skills.sh` does not exist.

- [ ] **Step 3: Add the installer library**

Create `home/.chezmoitemplates/lib/install/graphify-skills.sh`:

```bash
#!/usr/bin/env bash
# @file lib/install/graphify-skills.sh
# @brief Install Graphify agent skills.
# @description
#   Runs Graphify's user-scope skill installer for each platform in
#   GRAPHIFY_PLATFORMS. This file is sourceable from bats tests and injected
#   into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

#
# @description Check if graphify is installed.
#
function is_graphify_installed() {
  command -v graphify >/dev/null 2>&1
}

#
# @description Install Graphify skills for configured platforms.
#
function graphify_skills_install_main() {
  log_info "[graphify] Installing Graphify agent skills..."

  local platform
  for platform in "${GRAPHIFY_PLATFORMS[@]}"; do
    [ -n "${platform}" ] || continue
    graphify install --platform "${platform}"
  done

  log_info "[graphify] Graphify agent skills installed."
}

#
# @description Run the Graphify skill install flow.
#
function main() {
  if [ "${#GRAPHIFY_PLATFORMS[@]}" -eq 0 ]; then
    log_info "[graphify] No Graphify platforms to install."
    return 0
  fi

  if ! is_graphify_installed; then
    log_error "[graphify] graphify not found. Ensure run_onchange_03_install-uv-tools ran successfully."
    return 1
  fi

  graphify_skills_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
```

- [ ] **Step 4: Run the unit tests again**

Run: `mise exec -- bats tests/unit/lib/install/graphify-skills.bats`

Expected: PASS.

### Task 3: Darwin Graphify Run Script

**Files:**

- Create: `home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl`
- Modify: `tests/template/darwin-install-scripts.bats`

- [ ] **Step 1: Add failing template assertions**

Modify `tests/template/darwin-install-scripts.bats`:

```bash
GRAPHIFY_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl"
EMPTY_APM_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false,"apm":{"targets":{"shared":[],"personal":[],"work":[]}}}'
```

Add tests:

```bash
@test "darwin install script templates inject Graphify shell library" {
  assert_file_contains "$GRAPHIFY_TEMPLATE" '{{ template "lib/install/graphify-skills.sh" . }}'
}

@test "personal Graphify template renders agent and Claude platforms" {
  run render_template_with_data "$GRAPHIFY_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_output --partial 'GRAPHIFY_PLATFORMS=('
  assert_output --partial '"agents"'
  assert_output --partial '"claude"'
  assert_output --partial 'graphify_skills_install_main'
}

@test "work Graphify template renders no personal platforms" {
  run render_template_with_data "$GRAPHIFY_TEMPLATE" "$WORK_DATA"

  assert_success
  refute_output --partial '"agents"'
  refute_output --partial '"claude"'
  refute_output --partial 'graphify install --platform'
  refute_output --partial 'graphify_skills_install_main'
}

@test "empty APM target groups render no Graphify commands" {
  run render_template_with_data "$GRAPHIFY_TEMPLATE" "$EMPTY_APM_DATA"

  assert_success
  refute_output --partial 'GRAPHIFY_PLATFORMS=('
  refute_output --partial 'graphify install --platform'
  refute_output --partial 'graphify_skills_install_main'
}
```

- [ ] **Step 2: Run the failing template tests**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`

Expected: FAIL because the Graphify run script does not exist yet.

- [ ] **Step 3: Add the run-on-change template**

Create `home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl`:

```gotemplate
#!/usr/bin/env bash
# @file run_onchange_08_install-graphify-skills.sh
# @brief Install Graphify agent skills.
# @description APM data hash: {{ include ".chezmoidata/apm.yaml" | sha256sum }}
# @description active group helper hash: {{ include ".chezmoitemplates/lib/chezmoi/active-groups.json.tmpl" | sha256sum }}
# @description active group values helper hash: {{ include ".chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl" | sha256sum }}
{{- $targets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .apm.targets) | fromJson -}}
{{- $platforms := list -}}
{{- range $target := $targets -}}
{{- if eq $target "agent-skills" -}}
{{- $platforms = append $platforms "agents" -}}
{{- else if eq $target "claude" -}}
{{- $platforms = append $platforms "claude" -}}
{{- end -}}
{{- end -}}
{{- $hasPlatforms := gt (len $platforms) 0 -}}

{{ if and (eq .chezmoi.os "darwin") .personal $hasPlatforms }}
{{ template "lib/common/log.sh" . }}
GRAPHIFY_PLATFORMS=(
{{ range $platforms -}}
  "{{ . }}"
{{ end -}}
)
{{ template "lib/install/graphify-skills.sh" . }}
{{ end }}
```

- [ ] **Step 4: Run the template tests again**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`

Expected: PASS.

### Task 4: Shared Agent Instructions

**Files:**

- Modify: `home/.chezmoitemplates/AGENTS.md`
- Modify: `tests/template/agent-instructions.bats`

- [ ] **Step 1: Add failing instruction assertions**

Modify `tests/template/agent-instructions.bats` by adding this test:

```bash
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
```

- [ ] **Step 2: Run the failing instruction tests**

Run: `mise exec -- bats tests/template/agent-instructions.bats`

Expected: FAIL because the shared Graphify guidance is not present yet.

- [ ] **Step 3: Add the shared Graphify guidance**

Append this section to `home/.chezmoitemplates/AGENTS.md`:

```markdown
## Graphify

- Use the installed Graphify skill when the user invokes `/graphify`.
- If `graphify-out/graph.json` exists, prefer `graphify query`, `graphify path`, or `graphify explain` before raw file search for codebase questions.
- Read `GRAPH_REPORT.md` only for broad architecture review or when graph commands do not answer the question.
- Treat `graphify-out/` as per-repo data and do not create it from a global setup script.
```

- [ ] **Step 4: Run the instruction tests again**

Run: `mise exec -- bats tests/template/agent-instructions.bats`

Expected: PASS.

### Task 5: Final Verification

**Files:**

- Verify all changed files.

- [ ] **Step 1: Run targeted tests**

Run: `mise exec -- bats tests/unit/lib/install/graphify-skills.bats tests/template/darwin-install-scripts.bats tests/template/agent-instructions.bats`

Expected: PASS.

- [ ] **Step 2: Run shell syntax checks through existing template tests**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`

Expected: PASS, including rendered bash syntax validation.

- [ ] **Step 3: Run diff whitespace check**

Run: `git diff --check`

Expected: no output and exit code 0.

- [ ] **Step 4: Review final diff**

Run: `git diff -- docs/superpowers/specs/2026-06-24-graphify-global-agent-install-design.md docs/superpowers/plans/2026-06-24-graphify-global-agent-install.md home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl home/.chezmoitemplates/lib/install/graphify-skills.sh home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl home/.chezmoitemplates/AGENTS.md tests/template/darwin-install-scripts.bats tests/template/agent-instructions.bats tests/unit/lib/install/graphify-skills.bats`

Expected: only the planned files changed.
