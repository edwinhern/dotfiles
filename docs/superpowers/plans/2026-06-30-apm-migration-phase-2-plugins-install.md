# AI Plugins Install (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the hook-bearing plugins declared in `home/.chezmoidata/ai.yaml` (`caveman`, `superpowers`) for the active machine's agent target, replacing the retired apm install path.

**Architecture:** Mirror the `ai-skills` Phase-1 pattern (sourceable bash library + `run_onchange` chezmoi script + bats). The library is decomposed into small single-responsibility functions (Kaizen): a predicate, per-plugin installers, per-target loops, a dispatcher, and a thin orchestrator. Install branches on the active target: `claude-code` installs through the Claude marketplace CLI (`claude plugin marketplace add <source>` then `claude plugin install <name>@<marketplace>`); `github-copilot` installs the plugin source as a skill (`npx --yes skills add <source> -a github-copilot --global --copy --yes`), because Copilot has no plugin or hook runtime. Marketplaces and enabled plugins are also declared in the plain `home/dot_claude/settings.json`.

**Tech Stack:** chezmoi templates, bash, the `claude` CLI (`claude plugin ...`), the `skills` CLI (`npx skills`), bats.

**Spec:** `docs/superpowers/specs/2026-06-30-apm-to-claude-marketplace-migration-design.md` (sections: Plugins Design, Group and Target Data Model).

**Naming:** `ai-plugins` (not `claude-plugins`) — agnostic, matching the `ai.plugins` data namespace and the `ai-skills` sibling, because plugins install to both agents.

**Scope note:** Phase 2 of 7. Delivers plugins install on its own. The `06` run-script slot is free (the apm script was removed by prior cleanup). Phase 2 does not touch MCP, instructions, or apm teardown.

---

## Verification findings (resolved)

Confirmed live against the `claude plugin` CLI (read-only):

- **Marketplace list format:** `❯ <marketplace-name>` with a `Source: GitHub (owner/repo)` line under it.
- **Installed-plugin format:** `❯ <name>@<marketplace>` with `Status: ✔ enabled|✘ disabled`; skills-directory plugins list separately as `<name>@skills-dir`.
- **`caveman` already exists as `caveman@skills-dir`** (`~/.claude/skills/caveman`) from a prior run. Installing `caveman@caveman` (marketplace) adds a second copy. **Validate on real apply**; may warrant pruning the skills-dir copy in a later phase.
- **`claude plugin install` has no non-interactive flag** (`--config`, `--scope` only). A first-time trust prompt could block `chezmoi apply`. **Validate on real apply.**
- **Idempotency of `marketplace add` / re-`install` is untested** (testing mutates the machine). Decision: no idempotency guards — match `ai-skills`, collect per-plugin failures and warn (graceful, non-fatal). Add guards later only if re-run noise is observed (Kaizen JIT; respects the no-defensive-programming rule).

## File Structure

- Create: `home/.chezmoitemplates/lib/install/ai-plugins.sh` — sourceable install library; small functions, branches per target.
- Create: `home/.chezmoiscripts/darwin/run_onchange_06_install-ai-plugins.sh.tmpl` — chezmoi run script; resolves active targets and plugins, renders bash arrays, sources the library.
- Modify: `home/dot_claude/settings.json` — declare `caveman` + `superpowers-dev` marketplaces and enable `caveman@caveman` + `superpowers@superpowers-dev` (SuperWhisper stays `true`).
- Create: `tests/unit/lib/install/ai-plugins.bats` — behavior tests stubbing `claude` and `npx`.
- Modify: `tests/template/darwin-install-scripts.bats` — render tests for `run_onchange_06`.

## Data Contract

The run script passes the library two arrays:

- `AI_PLUGIN_TARGETS` — agent ids, e.g. `("claude-code")`. From `active-group-values` of `.ai.targets`.
- `AI_PLUGINS` — `"<name>|<marketplace>|<source>"` strings, e.g. `("caveman|caveman|JuliusBrussee/caveman" "superpowers|superpowers-dev|obra/superpowers")`. From `active-group-values` of `.ai.plugins`.

The `|` delimiter is safe: names, marketplace names, and `owner/repo` sources contain no `|`.

---

### Task 1: Install library (decomposed)

**Files:** Create `home/.chezmoitemplates/lib/install/ai-plugins.sh`; Test `tests/unit/lib/install/ai-plugins.bats`.

- [ ] **Step 1: Write the failing test file** — mirror `ai-skills.bats`. `setup()` stubs both `claude` and `npx` into `$BATS_TEST_TMPDIR/bin` (each `printf '%s\n' "$*" | tee -a` its own args file, then `exit "${<CLI>_EXIT_CODE:-0}"`), exports `PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"`. Helper: `_run_main() { run bash -c "source '$LOG_LIB' && source '$LIB' && $1 && main"; }`. Cases (fill bodies in the `ai-skills.bats` style — exact `assert_line`, `refute_line`, count asserts):

```bash
@test "claude-code target adds marketplace and installs each plugin" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman' 'superpowers|superpowers-dev|obra/superpowers')"
  assert_success
  assert_line "plugin marketplace add JuliusBrussee/caveman"
  assert_line "plugin install caveman@caveman"
  assert_line "plugin marketplace add obra/superpowers"
  assert_line "plugin install superpowers@superpowers-dev"
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "github-copilot target installs plugin source as a skill" {
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"
  assert_success
  assert_line "--yes skills add JuliusBrussee/caveman -a github-copilot --global --copy --yes"
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "both targets install every plugin to each" { ... claude add+install for each AND npx skills add for each ... }
@test "exits cleanly with no plugins"  { ... assert_line "[ai-plugins] No plugins to install." ; }
@test "exits cleanly with no targets"  { ... assert_line "[ai-plugins] No agent targets; nothing to install." ; }
@test "skips empty plugin entries"     { ... expected install count ; }
@test "skips empty target entries"     { ... expected install count ; }
@test "warns but succeeds when a plugin fails" { CLAUDE_EXIT_CODE=1 ... assert_success ; assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:" ; assert_line "  - caveman" ; }
@test "unknown target warns and skips" { ... assert_line "warn: [ai-plugins] unknown target 'grok'; skipping." ; }
@test "fails when claude is missing for a claude-code target" { rm claude stub; PATH=".../bin:/bin"; assert_failure 1; assert_line "error: [ai-plugins] claude CLI not found. Ensure Claude Code is installed." ; }
@test "fails when npx is missing for a github-copilot target"  { rm npx stub; PATH=".../bin:/bin"; assert_failure 1; assert_line "error: [ai-plugins] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)." ; }
```

- [ ] **Step 2: Run the tests to verify they fail** (`bats tests/unit/lib/install/ai-plugins.bats` — lib missing).

- [ ] **Step 3: Write the library** — small functions, each one responsibility. `set -Eeuo pipefail`; all array expansions use the `[@]-` default or a count guard (bash 3.2 safe); the per-plugin installers are always called in a `|| failed+=(...)` context so `set -e` is suppressed inside them.

```bash
#!/usr/bin/env bash
# @file lib/install/ai-plugins.sh
# @brief Install cross-agent AI plugins for the active agent targets.
# @description
#   Installs each plugin in AI_PLUGINS for every agent in AI_PLUGIN_TARGETS.
#   Claude Code plugins install through the marketplace CLI; GitHub Copilot has
#   no plugin runtime, so the plugin source installs as a skill instead.
#   Sourceable from bats tests and injected into chezmoi run scripts.

set -Eeuo pipefail

# @description True when AI_PLUGINS holds at least one non-empty entry.
function _ai_plugins_have_any() {
  local entry
  for entry in "${AI_PLUGINS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    return 0
  done
  return 1
}

# @description Warn about the plugins that failed to install.
# @arg $@ string Names of the plugins that failed.
function _ai_plugins_report_failures() {
  log_warn "[ai-plugins] ${#} plugin(s) failed to install:"
  printf '  - %s\n' "$@" >&2
}

# @description Add one plugin's marketplace and install it into Claude Code.
# @arg $1 string Plugin name.  @arg $2 string Marketplace.  @arg $3 string Source repo.
function _ai_plugins_add_to_claude() {
  local name="$1" marketplace="$2" src="$3"
  claude plugin marketplace add "${src}" &&
    claude plugin install "${name}@${marketplace}"
}

# @description Install one plugin source into GitHub Copilot as a skill.
# @arg $1 string Source repo.
function _ai_plugins_add_to_copilot() {
  npx --yes skills add "$1" -a github-copilot --global --copy --yes
}

# @description Install every plugin for the Claude Code target.
# @exitcode 1 The claude CLI is missing.
function _ai_plugins_for_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    log_error "[ai-plugins] claude CLI not found. Ensure Claude Code is installed."
    return 1
  fi
  local -a failed=()
  local entry name marketplace src rest
  for entry in "${AI_PLUGINS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    name="${entry%%|*}"
    rest="${entry#*|}"
    marketplace="${rest%%|*}"
    src="${rest##*|}"
    _ai_plugins_add_to_claude "${name}" "${marketplace}" "${src}" || failed+=("${name}")
  done
  if ((${#failed[@]} > 0)); then
    _ai_plugins_report_failures "${failed[@]}"
  fi
}

# @description Install every plugin for the GitHub Copilot target.
# @exitcode 1 npx is missing.
function _ai_plugins_for_copilot() {
  if ! command -v npx >/dev/null 2>&1; then
    log_error "[ai-plugins] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
    return 1
  fi
  local -a failed=()
  local entry name src
  for entry in "${AI_PLUGINS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    name="${entry%%|*}"
    src="${entry##*|}"
    _ai_plugins_add_to_copilot "${src}" || failed+=("${name}")
  done
  if ((${#failed[@]} > 0)); then
    _ai_plugins_report_failures "${failed[@]}"
  fi
}

# @description Route one agent target to its installer.
# @arg $1 string Agent target id.
function _ai_plugins_for_target() {
  case "$1" in
    claude-code) _ai_plugins_for_claude_code ;;
    github-copilot) _ai_plugins_for_copilot ;;
    *)
      log_warn "[ai-plugins] unknown target '$1'; skipping."
      return 0
      ;;
  esac
}

# @description Install the active plugins for each active agent target.
# @exitcode 0 Installed, or nothing to do.
# @exitcode 1 A required CLI is missing for a requested target.
function ai_plugins_install_main() {
  if ! _ai_plugins_have_any; then
    log_info "[ai-plugins] No plugins to install."
    return 0
  fi
  local -a targets=()
  local target
  for target in "${AI_PLUGIN_TARGETS[@]-}"; do
    [[ -z "${target}" ]] && continue
    targets+=("${target}")
  done
  if ((${#targets[@]} == 0)); then
    log_info "[ai-plugins] No agent targets; nothing to install."
    return 0
  fi
  log_info "[ai-plugins] Installing AI plugins..."
  for target in "${targets[@]}"; do
    _ai_plugins_for_target "${target}" || return 1
  done
  log_info "[ai-plugins] AI plugins installed."
}

function main() { ai_plugins_install_main; }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  main
fi
```

- [ ] **Step 4: Run the tests to verify they pass.**
- [ ] **Step 5: `shellcheck home/.chezmoitemplates/lib/install/ai-plugins.sh`.**
- [ ] **Step 6: Commit** `feat: add ai-plugins install library` (DOT-43).

---

### Task 2: run script + settings.json declaration

**Files:** Create `home/.chezmoiscripts/darwin/run_onchange_06_install-ai-plugins.sh.tmpl`; Modify `home/dot_claude/settings.json`.

- [ ] **Step 1: Write the run script** (mirror `run_onchange_09`; no local-content hash — plugins come from external sources):

```
#!/usr/bin/env bash
# @file run_onchange_06_install-ai-plugins.sh
# @brief Install cross-agent AI plugins.
# @description AI data hash: {{ include ".chezmoidata/ai.yaml" | sha256sum }}
{{- $activeTargets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.targets) | fromJson -}}
{{- $activePlugins := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.plugins) | fromJson -}}

{{ if and (eq .chezmoi.os "darwin") (gt (len $activeTargets) 0) (gt (len $activePlugins) 0) }}
{{ template "lib/common/log.sh" . }}
{{ template "lib/common/install-prelude.sh" . }}
AI_PLUGIN_TARGETS=(
{{ range $activeTargets -}}
  "{{ . }}"
{{ end -}}
)
AI_PLUGINS=(
{{ range $activePlugins -}}
  "{{ .name }}|{{ .marketplace }}|{{ .source }}"
{{ end -}}
)
{{ template "lib/install/ai-plugins.sh" . }}
{{ end }}
```

- [ ] **Step 2: Verify the render** for personal (`claude-code`, both plugins) and work (`github-copilot`, both plugins) via `chezmoi execute-template --source home --override-data ...`.

- [ ] **Step 3: Declare marketplaces and enabled plugins in `home/dot_claude/settings.json`** (plain JSON):

```json
"enabledPlugins": {
  "superwhisper@superwhisper": true,
  "caveman@caveman": true,
  "superpowers@superpowers-dev": true
},
"extraKnownMarketplaces": {
  "superwhisper": { "source": { "source": "github", "repo": "superultrainc/superwhisper-claude-code" } },
  "caveman": { "source": { "source": "github", "repo": "JuliusBrussee/caveman" } },
  "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } }
}
```

- [ ] **Step 4: Commit** `feat: add ai-plugins run_onchange script and settings` (DOT-43).

---

### Task 3: Template render tests

**Files:** Modify `tests/template/darwin-install-scripts.bats`.

- [ ] **Step 1:** Add `PLUGINS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_06_install-ai-plugins.sh.tmpl"`, an inject-lib assertion (`{{ template "lib/install/ai-plugins.sh" . }}`), a prelude-injection assertion, and render tests:

```bash
@test "personal plugins template targets claude-code and includes both plugins" {
  run render_chezmoi_template "$PLUGINS_TEMPLATE" "$DARWIN_DATA"
  assert_success
  assert_line 'AI_PLUGIN_TARGETS=('
  assert_line --partial '"claude-code"'
  assert_line --partial '"caveman|caveman|JuliusBrussee/caveman"'
  assert_line --partial '"superpowers|superpowers-dev|obra/superpowers"'
  assert_line --partial 'ai_plugins_install_main'
}

@test "work plugins template targets github-copilot" {
  run render_chezmoi_template "$PLUGINS_TEMPLATE" "$WORK_DATA"
  assert_success
  assert_line --partial '"github-copilot"'
  refute_line --partial '"claude-code"'
}

@test "empty AI target groups render no plugin commands" {
  run render_chezmoi_template "$PLUGINS_TEMPLATE" "$EMPTY_AI_DATA"
  assert_success
  refute_line 'AI_PLUGIN_TARGETS=('
  refute_line --partial 'ai_plugins_install_main'
}
```

The existing glob tests (bash shebang, `bash -n`) auto-cover the new script.

- [ ] **Step 2:** Run `bats tests/unit/lib/install/ai-plugins.bats tests/template/darwin-install-scripts.bats`; then `mise run check`.
- [ ] **Step 3: Commit** `test: add ai-plugins template render tests` (DOT-43).

---

## Self-Review

- **Spec coverage (Plugins Design):** dual path per target (Task 1), `run_onchange_06` replaces the apm script and gates darwin (Task 2), settings.json declares marketplaces + enabled plugins (Task 2). Covered.
- **Naming/type consistency:** `ai-plugins`, `AI_PLUGIN_TARGETS`, `AI_PLUGINS`, `<name>|<marketplace>|<source>`, `ai_plugins_install_main` identical across library, run script, and tests.
- **Kaizen decomposition:** predicate, per-plugin installers, per-target loops, dispatcher, orchestrator — each one responsibility, `set -Eeuo` and bash-3.2 safe.
- **Known risks for real-apply validation:** `claude plugin install` interactivity/hang; `caveman@skills-dir` duplicate; `marketplace add` re-run idempotency. All degrade to a warned failure, not data loss.
- **Out of Phase 2 scope:** MCP delivery, instructions wiring, apm teardown.
