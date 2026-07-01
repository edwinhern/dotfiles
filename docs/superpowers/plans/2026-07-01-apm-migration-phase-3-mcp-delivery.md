# APM Migration Phase 3: MCP Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the MCP servers declared in `ai.yaml` to Claude Code (imperatively via `claude mcp add`) and to GitHub Copilot (declaratively via rendered config files), driven by the same group and target data as skills and plugins.

**Architecture:** One `ai.mcp` data source, two delivery idioms. Claude Code owns mutable state in `~/.claude.json`, so a `run_onchange` shell script registers servers with `claude mcp add` and stays idempotent via `claude mcp get`. Copilot config files are standalone, so chezmoi renders them whole. Each surface gates on its active target, so the machine's active MCP set (shared plus personal on a Claude machine, shared plus work on a Copilot machine) routes to the correct surface for free.

**Tech Stack:** chezmoi templates, bash 3.2 (macOS), bats, `claude` CLI, sprig template functions (`dict`, `set`, `has`, `toPrettyJson`).

---

## Background

`ai.yaml` already declares MCP servers, grouped like every other install list:

```yaml
mcp:
  shared:
    - { name: grep, transport: http, url: https://mcp.grep.app }
  personal:
    - { name: tavily, transport: http, url: https://mcp.tavily.com/mcp/ }
  work:
    - { name: figma, transport: http, url: https://mcp.figma.com/mcp }
    - { name: jira, transport: http, url: https://mcp.atlassian.com/v1/mcp }
```

`lib/chezmoi/active-group-values.json.tmpl` flattens the active groups (always `shared`; plus `personal` and/or `work`) into one list. On a personal/`claude-code` machine that yields `grep, tavily`; on a work/`github-copilot` machine it yields `grep, figma, jira`. The spec's routing (tavily to Claude only, figma and jira to Copilot only, grep to both) is the natural result of the group-to-target mapping.

Confirmed target schemas:

- Claude Code: `claude mcp add --scope user --transport http <name> <url>`. Idempotent guard: `claude mcp get <name>`.
- Copilot CLI (`~/.copilot/mcp-config.json`): `{ "mcpServers": { "<name>": { "type": "http", "url": "<url>", "tools": ["*"] } } }`.
- VS Code Copilot (`~/Library/Application Support/Code/User/mcp.json`): `{ "servers": { "<name>": { "type": "http", "url": "<url>" } } }`.

## File Structure

**Create:**

- `home/.chezmoitemplates/lib/install/ai-mcp.sh` — Claude-only MCP registration library, decomposed into small functions, mirroring `ai-skills.sh`.
- `tests/unit/lib/install/ai-mcp.bats` — behavior tests for the library, mirroring `ai-plugins.bats`.
- `home/.chezmoiscripts/darwin/run_onchange_08_install-ai-mcp.sh.tmpl` — renders the active Claude MCP list and injects the library.
- `home/dot_copilot/mcp-config.json.tmpl` — Copilot CLI MCP config, rendered from `ai.mcp`.
- `home/Library/Application Support/Code/User/mcp.json.tmpl` — VS Code Copilot MCP config, rendered from `ai.mcp`.
- `tests/template/mcp-config.bats` — render tests for the two declarative Copilot configs.

**Rename (honor "graphify at the end"):**

- `home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl` -> `run_onchange_09_install-graphify-skills.sh.tmpl` (and its `@file` comment).

**Modify:**

- `tests/template/darwin-install-scripts.bats` — repoint `GRAPHIFY_TEMPLATE` to `_09_`; add the MCP run-script constant and tests.
- Delete: `home/dot_copilot/mcp-config.json` and `home/Library/Application Support/Code/User/mcp.json` (replaced by their `.tmpl` versions).

## Design Notes

- The Claude run script injects `log.sh` and `install-prelude.sh` before the library, matching every sibling install script (standardized scaffold). `ai-mcp.sh` itself only calls `log_*`, so its self-exec guard sources `log.sh` only, like `ai-plugins.sh`.
- The MCP run script gates on `has "claude-code" $activeTargets`, not merely `len > 0`, because Copilot MCP is delivered by the declarative templates, not this script.
- The Copilot templates always apply; when `github-copilot` is not an active target they render an empty server map, matching today's static `{}` files.

---

### Task 1: Rename the Graphify script to slot 09

**Files:**

- Rename: `home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl` -> `home/.chezmoiscripts/darwin/run_onchange_09_install-graphify-skills.sh.tmpl`
- Modify: the renamed file's `@file` line
- Modify: `tests/template/darwin-install-scripts.bats:11`

- [ ] **Step 1: Rename the script file**

```bash
git mv "home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl" \
       "home/.chezmoiscripts/darwin/run_onchange_09_install-graphify-skills.sh.tmpl"
```

- [ ] **Step 2: Update the `@file` comment inside the renamed file**

Change line 2 from:

```bash
# @file run_onchange_08_install-graphify-skills.sh
```

to:

```bash
# @file run_onchange_09_install-graphify-skills.sh
```

- [ ] **Step 3: Repoint the test constant**

In `tests/template/darwin-install-scripts.bats` line 11, change:

```bash
GRAPHIFY_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl"
```

to:

```bash
GRAPHIFY_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_09_install-graphify-skills.sh.tmpl"
```

- [ ] **Step 4: Run the template tests to verify the rename is clean**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`
Expected: all tests PASS (Graphify inject, render, and empty tests still green).

- [ ] **Step 5: Commit**

```bash
git add home/.chezmoiscripts/darwin/run_onchange_09_install-graphify-skills.sh.tmpl tests/template/darwin-install-scripts.bats
git commit -m "refactor: renumber graphify install script to 09"
```

---

### Task 2: MCP registration library with unit tests (TDD)

**Files:**

- Test: `tests/unit/lib/install/ai-mcp.bats`
- Create: `home/.chezmoitemplates/lib/install/ai-mcp.sh`

- [ ] **Step 1: Write the failing unit tests**

Create `tests/unit/lib/install/ai-mcp.bats`:

```bash
#!/usr/bin/env bats
# @file tests/unit/lib/install/ai-mcp.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/ai-mcp.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/ai-mcp.sh"

setup() {
  export CLAUDE_ARGS_FILE="$BATS_TEST_TMPDIR/claude-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  # Default stub: `mcp get` reports "not found" (exit 1) so `mcp add` runs.
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
[[ "$1 $2" == "mcp get" ]] && exit 1
exit "${CLAUDE_EXIT_CODE:-0}"
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
}

_run_main() {
  run bash -c "source '$LOG_LIB' && source '$LIB' && $1 && main"
}

@test "main: registers each server with user scope and transport" {
  _run_main "AI_MCP=('grep|http|https://mcp.grep.app' 'tavily|http|https://mcp.tavily.com/mcp/')"

  assert_success
  assert_line "[ai-mcp] Registering MCP servers..."
  assert_line "[ai-mcp] MCP servers registered."
  assert_line "mcp add --scope user --transport http grep https://mcp.grep.app"
  assert_line "mcp add --scope user --transport http tavily https://mcp.tavily.com/mcp/"
}

@test "main: skips a server that is already registered" {
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
# grep already exists; tavily does not.
[[ "$1 $2" == "mcp get" && "$3" == "grep" ]] && exit 0
[[ "$1 $2" == "mcp get" ]] && exit 1
exit 0
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  _run_main "AI_MCP=('grep|http|https://mcp.grep.app' 'tavily|http|https://mcp.tavily.com/mcp/')"

  assert_success
  assert_line "[ai-mcp] grep already registered; skipping."
  refute_line "mcp add --scope user --transport http grep https://mcp.grep.app"
  assert_line "mcp add --scope user --transport http tavily https://mcp.tavily.com/mcp/"
}

@test "main: exits cleanly with no servers" {
  _run_main "AI_MCP=()"

  assert_success
  assert_line "[ai-mcp] No MCP servers to register."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "main: skips empty server entries" {
  _run_main "AI_MCP=('grep|http:x' '' 'jira|http|https://mcp.atlassian.com/v1/mcp')"

  assert_success
  assert_line "mcp add --scope user --transport http jira https://mcp.atlassian.com/v1/mcp"
}

@test "main: warns but succeeds when a server fails to register" {
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
[[ "$1 $2" == "mcp get" ]] && exit 1
[[ "$1 $2" == "mcp add" ]] && exit 1
exit 0
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  _run_main "AI_MCP=('grep|http|https://mcp.grep.app')"

  assert_success
  assert_line "warn: [ai-mcp] 1 server(s) failed to register:"
  assert_line "  - grep"
  assert_line "[ai-mcp] MCP servers registered."
}

@test "main: fails when claude is missing" {
  rm -f "$BATS_TEST_TMPDIR/bin/claude"
  # Drop /usr/bin so a host-installed claude cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_MCP=('grep|http|https://mcp.grep.app')"

  assert_failure 1
  assert_line "error: [ai-mcp] claude CLI not found. Ensure Claude Code is installed."
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- bats tests/unit/lib/install/ai-mcp.bats`
Expected: FAIL (the library file does not exist yet).

- [ ] **Step 3: Write the library**

Create `home/.chezmoitemplates/lib/install/ai-mcp.sh`:

```bash
#!/usr/bin/env bash
# @file lib/install/ai-mcp.sh
# @brief Register cross-agent MCP servers on Claude Code.
# @description
#   Runs `claude mcp add` for each server in AI_MCP, scoped to the user. A
#   `claude mcp get` check keeps the flow idempotent by skipping a server that
#   is already registered. Copilot MCP arrives through rendered config files,
#   so this library targets Claude Code only. Sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description True when AI_MCP holds at least one non-empty entry.
# @exitcode 0 A server is present.
# @exitcode 1 No servers.
#
function _ai_mcp_have_any() {
  local entry
  for entry in "${AI_MCP[@]-}"; do
    [[ -z "${entry}" ]] && continue
    return 0
  done
  return 1
}

#
# @description Warn about the MCP servers that failed to register.
# @arg $@ string Names of the servers that failed.
#
function _ai_mcp_report_failures() {
  log_warn "[ai-mcp] ${#} server(s) failed to register:"
  printf '  - %s\n' "$@" >&2
}

#
# @description Register each MCP server on Claude Code, skipping existing ones.
# @exitcode 0 Registered, or nothing to do.
# @exitcode 1 The claude CLI is missing.
#
function ai_mcp_install_main() {
  if ! _ai_mcp_have_any; then
    log_info "[ai-mcp] No MCP servers to register."
    return 0
  fi

  if ! command -v claude >/dev/null 2>&1; then
    log_error "[ai-mcp] claude CLI not found. Ensure Claude Code is installed."
    return 1
  fi

  log_info "[ai-mcp] Registering MCP servers..."

  local -a failed=()
  local entry name transport url rest
  for entry in "${AI_MCP[@]-}"; do
    [[ -z "${entry}" ]] && continue
    name="${entry%%|*}"
    rest="${entry#*|}"
    transport="${rest%%|*}"
    url="${rest##*|}"

    if claude mcp get "${name}" >/dev/null 2>&1; then
      log_info "[ai-mcp] ${name} already registered; skipping."
      continue
    fi

    claude mcp add --scope user --transport "${transport}" "${name}" "${url}" || failed+=("${name}")
  done

  if ((${#failed[@]} > 0)); then
    _ai_mcp_report_failures "${failed[@]}"
  fi

  log_info "[ai-mcp] MCP servers registered."
}

#
# @description Run the AI MCP registration flow.
#
function main() {
  ai_mcp_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # When run directly, pull in the shared log library that chezmoi otherwise
  # concatenates ahead of this file.
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  main
fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mise exec -- bats tests/unit/lib/install/ai-mcp.bats`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add home/.chezmoitemplates/lib/install/ai-mcp.sh tests/unit/lib/install/ai-mcp.bats
git commit -m "feat: add MCP registration library for claude code"
```

---

### Task 3: Claude MCP run script with template tests

**Files:**

- Create: `home/.chezmoiscripts/darwin/run_onchange_08_install-ai-mcp.sh.tmpl`
- Modify: `tests/template/darwin-install-scripts.bats`

- [ ] **Step 1: Add the template test constant and tests**

In `tests/template/darwin-install-scripts.bats`, add near the other template constants (after the AI plugins constant):

```bash
AI_MCP_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_08_install-ai-mcp.sh.tmpl"
```

Add these tests (mirroring the AI plugins tests, using the file's existing `render_chezmoi_template`, `DARWIN_DATA`, `WORK_DATA`, and `EMPTY_AI_DATA` helpers):

```bash
@test "darwin install script templates inject AI MCP shell library" {
  assert_file_contains "$AI_MCP_TEMPLATE" '{{ template "lib/install/ai-mcp.sh" . }}'
}

@test "darwin install script templates inject the prelude before AI MCP" {
  local prelude
  prelude='{{ template "lib/common/install-prelude.sh" . }}'
  assert_file_contains "$AI_MCP_TEMPLATE" "$prelude"
}

@test "personal AI MCP template registers shared and personal servers" {
  run render_chezmoi_template "$AI_MCP_TEMPLATE" "$DARWIN_DATA"
  assert_success
  assert_line --partial '"grep|http|https://mcp.grep.app"'
  assert_line --partial '"tavily|http|https://mcp.tavily.com/mcp/"'
}

@test "work AI MCP template registers no Claude servers" {
  run render_chezmoi_template "$AI_MCP_TEMPLATE" "$WORK_DATA"
  assert_success
  refute_line --partial 'lib/install/ai-mcp.sh'
}

@test "empty AI target groups render no AI MCP commands" {
  run render_chezmoi_template "$AI_MCP_TEMPLATE" "$EMPTY_AI_DATA"
  assert_success
  refute_line --partial 'lib/install/ai-mcp.sh'
}
```

Note: the "work" render produces no Claude MCP block because the gate requires `claude-code` in the active targets; a work machine targets `github-copilot`, so the `if` is false and the library is not injected.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`
Expected: the five new tests FAIL (template file does not exist yet).

- [ ] **Step 3: Create the run script template**

Create `home/.chezmoiscripts/darwin/run_onchange_08_install-ai-mcp.sh.tmpl`:

```bash
#!/usr/bin/env bash
# @file run_onchange_08_install-ai-mcp.sh
# @brief Register cross-agent MCP servers.
# @description AI data hash: {{ include ".chezmoidata/ai.yaml" | sha256sum }}
{{- $activeTargets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.targets) | fromJson -}}
{{- $activeMcp := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.mcp) | fromJson -}}

{{ if and (eq .chezmoi.os "darwin") (has "claude-code" $activeTargets) (gt (len $activeMcp) 0) }}
{{ template "lib/common/log.sh" . }}
{{ template "lib/common/install-prelude.sh" . }}
AI_MCP=(
{{ range $activeMcp -}}
  "{{ .name }}|{{ .transport }}|{{ .url }}"
{{ end -}}
)
{{ template "lib/install/ai-mcp.sh" . }}
{{ end }}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add home/.chezmoiscripts/darwin/run_onchange_08_install-ai-mcp.sh.tmpl tests/template/darwin-install-scripts.bats
git commit -m "feat: add claude code MCP install run script"
```

---

### Task 4: Copilot MCP config templates with render tests

**Files:**

- Create: `home/dot_copilot/mcp-config.json.tmpl`
- Create: `home/Library/Application Support/Code/User/mcp.json.tmpl`
- Delete: `home/dot_copilot/mcp-config.json`, `home/Library/Application Support/Code/User/mcp.json`
- Create: `tests/template/mcp-config.bats`

- [ ] **Step 1: Write the failing render tests**

Create `tests/template/mcp-config.bats`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- bats tests/template/mcp-config.bats`
Expected: FAIL (template files do not exist yet).

- [ ] **Step 3: Create the Copilot CLI template and remove the static file**

```bash
git rm home/dot_copilot/mcp-config.json
```

Create `home/dot_copilot/mcp-config.json.tmpl`:

```
{{- $activeTargets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.targets) | fromJson -}}
{{- $activeMcp := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.mcp) | fromJson -}}
{{- $servers := dict -}}
{{- if has "github-copilot" $activeTargets -}}
{{- range $activeMcp -}}
{{- $_ := set $servers .name (dict "type" .transport "url" .url "tools" (list "*")) -}}
{{- end -}}
{{- end -}}
{{ dict "mcpServers" $servers | toPrettyJson }}
```

- [ ] **Step 4: Create the VS Code template and remove the static file**

```bash
git rm "home/Library/Application Support/Code/User/mcp.json"
```

Create `home/Library/Application Support/Code/User/mcp.json.tmpl`:

```
{{- $activeTargets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.targets) | fromJson -}}
{{- $activeMcp := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.mcp) | fromJson -}}
{{- $servers := dict -}}
{{- if has "github-copilot" $activeTargets -}}
{{- range $activeMcp -}}
{{- $_ := set $servers .name (dict "type" .transport "url" .url) -}}
{{- end -}}
{{- end -}}
{{ dict "servers" $servers | toPrettyJson }}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mise exec -- bats tests/template/mcp-config.bats`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add home/dot_copilot/mcp-config.json.tmpl "home/Library/Application Support/Code/User/mcp.json.tmpl" tests/template/mcp-config.bats
git add -u home/dot_copilot "home/Library/Application Support/Code/User"
git commit -m "feat: render copilot MCP config from ai.yaml"
```

---

### Task 5: Full verification and apply

**Files:** none (verification only)

- [ ] **Step 1: Run the full check suite**

Run: `mise run check`
Expected: treefmt clean and all bats tests PASS.

- [ ] **Step 2: Preview the apply on this (personal) machine**

Run: `chezmoi diff --source home | rg -A3 -i 'mcp'`
Expected: `~/.copilot/mcp-config.json` shows `"mcpServers": {}` (unchanged), `~/Library/.../Code/User/mcp.json` shows `"servers": {}`, and the new `run_onchange_08_install-ai-mcp` script is queued.

- [ ] **Step 3: Apply**

Run: `mise update`
Expected: the run script registers `grep` and `tavily` on Claude Code (or skips them if already present). Confirm with `claude mcp list`.

- [ ] **Step 4: Confirm idempotency**

Run: `mise update` a second time.
Expected: the MCP script logs `already registered; skipping.` for each server and adds nothing.

- [ ] **Step 5: Verify the Linear issue and open the PR**

Ensure a Linear `DOT-*` issue tracks Phase 3, move it to `In Review`, and open the PR from the `DOT-*` branch with `Refs DOT-XXX` in the body.

## Self-Review

- **Spec coverage:** Claude `claude mcp add` script (spec "MCP Design"), Copilot CLI `mcp-config.json` and VS Code `mcp.json` templates (spec lines 143 to 148), `tavily` personal to Claude only and `grep` to both (spec line 212) — all covered by the group-to-target gating.
- **Type consistency:** the `name|transport|url` field order is identical in the run-script render (`"{{ .name }}|{{ .transport }}|{{ .url }}"`) and the library parse (`%%|`, `#*|`, `##*|`). The library function names (`_ai_mcp_have_any`, `_ai_mcp_report_failures`, `ai_mcp_install_main`, `main`) match between the library and its tests.
- **Placeholder scan:** every step contains the actual file content or command; no TBDs.
