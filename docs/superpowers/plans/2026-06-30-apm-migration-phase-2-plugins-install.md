# Claude Plugins Install (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the hook-bearing plugins declared in `home/.chezmoidata/ai.yaml` (`caveman`, `superpowers`) for the active machine's agent target, replacing the retired apm install path.

**Architecture:** Mirror the `ai-skills` Phase-1 pattern (sourceable bash library + `run_onchange` chezmoi script + bats). The difference is a dual install path branched on the active target: `claude-code` installs through the Claude marketplace CLI (`claude plugin marketplace add` then `claude plugin install <name>@<marketplace>`); `github-copilot` installs the plugin source as a skill (`npx --yes skills add <source> -a github-copilot --global --copy --yes`), because Copilot has no plugin or hook runtime. The Claude marketplaces and enabled plugins are also declared in the plain `home/dot_claude/settings.json`.

**Tech Stack:** chezmoi templates, bash, the `claude` CLI (`claude plugin ...`), the `skills` CLI (`npx skills`), bats.

**Spec:** `docs/superpowers/specs/2026-06-30-apm-to-claude-marketplace-migration-design.md` (sections: Plugins Design, Group and Target Data Model).

**Scope note:** This is Phase 2 of 7. It delivers plugins install on its own. The `06` run-script slot is free (the apm script was removed by prior cleanup). Phase 2 does not touch MCP, instructions, or the remaining apm teardown.

---

## Pre-Implementation Verification

Before writing the library, confirm these against the real environment (a `verify` workflow or direct read), because the reference code below assumes them:

- **`claude plugin marketplace list` output format** — how a configured marketplace is named/printed, so the idempotency check can grep for it. Confirm whether `marketplace add <source>` is already idempotent (re-add is a no-op) — if so, the pre-check can be dropped.
- **`claude plugin list` output format** — how an installed plugin appears (`<name>@<marketplace>`?), for the install idempotency check.
- **`claude plugin install` exit behavior** on an already-installed plugin (0 vs non-zero), and whether it prompts (needs a non-interactive flag).
- **`claude` presence during `chezmoi apply`** — same first-boot PATH caveat as `npx` in Phase 1 (mise shims). Match the Phase-1 decision: hard-fail if the required CLI is absent.

## File Structure

- Create: `home/.chezmoitemplates/lib/install/claude-plugins.sh` — sourceable install library; branches per target and installs each plugin.
- Create: `home/.chezmoiscripts/darwin/run_onchange_06_install-claude-plugins.sh.tmpl` — chezmoi run script; resolves active targets and plugins from `ai.yaml`, renders bash arrays, sources the library.
- Modify: `home/dot_claude/settings.json` — add `caveman` and `superpowers-dev` to `extraKnownMarketplaces` and enable `caveman@caveman` and `superpowers@superpowers-dev` in `enabledPlugins`.
- Create: `tests/unit/lib/install/claude-plugins.bats` — behavior tests, stubbing `claude` and `npx`.
- Modify: `tests/template/darwin-install-scripts.bats` — add render tests for `run_onchange_06`.

## Data Contract

The run script passes the library:

- `AI_PLUGIN_TARGETS` — bash array of agent ids, e.g. `("claude-code")`. From `active-group-values` of `.ai.targets`.
- `AI_PLUGINS` — bash array of `"<name>|<marketplace>|<source>"` strings, e.g. `("caveman|caveman|JuliusBrussee/caveman" "superpowers|superpowers-dev|obra/superpowers")`. From `active-group-values` of `.ai.plugins`.

The `|` delimiter is safe: plugin names, marketplace names, and sources (`owner/repo`) contain no `|`.

---

### Task 1: Install library

**Files:** Create `home/.chezmoitemplates/lib/install/claude-plugins.sh`; Test `tests/unit/lib/install/claude-plugins.bats`.

- [ ] **Step 1: Write the failing test file**

Create `tests/unit/lib/install/claude-plugins.bats`, mirroring `ai-skills.bats`: stub both `claude` and `npx` into `$BATS_TEST_TMPDIR/bin` (each `printf '%s\n' "$*" | tee -a` its own args file), restrict PATH, source `log.sh` + `install-prelude.sh` + the lib, then run `main`. Cases:

```bash
@test "claude-code target: adds marketplace and installs each plugin" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman' 'superpowers|superpowers-dev|obra/superpowers')"
  assert_success
  assert_line --partial "plugin marketplace add JuliusBrussee/caveman"
  assert_line --partial "plugin install caveman@caveman"
  assert_line --partial "plugin marketplace add obra/superpowers"
  assert_line --partial "plugin install superpowers@superpowers-dev"
}

@test "github-copilot target: installs plugin source as a skill" {
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"
  assert_success
  assert_line "--yes skills add JuliusBrussee/caveman -a github-copilot --global --copy --yes"
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "exits cleanly with no plugins" { ... assert_line "[claude-plugins] No plugins to install." ; }
@test "exits cleanly with no targets" { ... assert_line "[claude-plugins] No agent targets; nothing to install." ; }
@test "skips empty plugin entries" { ... count == expected ; }
@test "warns but succeeds when a plugin fails" { ... export CLAUDE_EXIT_CODE=1 ... assert_line "warn: [claude-plugins] ..." ; assert_success ; }
@test "fails when the claude CLI is missing for a claude-code target" { rm claude stub; assert_failure 1; assert_line "error: [claude-plugins] claude CLI not found. ..." ; }
@test "fails when npx is missing for a github-copilot target" { rm npx stub; assert_failure 1; assert_line "error: [claude-plugins] npx not found. ..." ; }
```

Fill each case with full bodies during implementation, matching the `ai-skills.bats` style (exact `assert_line`, PATH-shim stubs, `refute_line` where appropriate). Add idempotency cases once the Pre-Implementation Verification pins the `claude plugin list` / `marketplace list` formats.

- [ ] **Step 2: Run the tests to verify they fail** (`bats tests/unit/lib/install/claude-plugins.bats` — lib missing).

- [ ] **Step 3: Write the install library**

Create `home/.chezmoitemplates/lib/install/claude-plugins.sh`, mirroring `ai-skills.sh` (shebang, `set -Eeuo pipefail`, shdoc header, `claude_plugins_install_main` + `main` + the `BASH_SOURCE` self-exec guard sourcing `log.sh`). Reference body:

```bash
function claude_plugins_install_main() {
  # return early with a log_info if AI_PLUGINS has no non-empty entry, or AI_PLUGIN_TARGETS is empty.
  local failed=() target entry name marketplace source rest
  for target in "${AI_PLUGIN_TARGETS[@]-}"; do
    [[ -z "${target}" ]] && continue
    case "${target}" in
      claude-code)
        command -v claude >/dev/null 2>&1 || { log_error "[claude-plugins] claude CLI not found. Ensure Claude Code is installed."; return 1; }
        for entry in "${AI_PLUGINS[@]-}"; do
          [[ -z "${entry}" ]] && continue
          name="${entry%%|*}"; rest="${entry#*|}"; marketplace="${rest%%|*}"; source="${rest#*|}"
          claude plugin marketplace add "${source}"    || failed+=("${name} (marketplace)")
          claude plugin install "${name}@${marketplace}" || failed+=("${name}")
        done
        ;;
      github-copilot)
        command -v npx >/dev/null 2>&1 || { log_error "[claude-plugins] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."; return 1; }
        for entry in "${AI_PLUGINS[@]-}"; do
          [[ -z "${entry}" ]] && continue
          name="${entry%%|*}"; rest="${entry#*|}"; source="${rest#*|}"
          npx --yes skills add "${source}" -a github-copilot --global --copy --yes || failed+=("${name}")
        done
        ;;
      *) log_warn "[claude-plugins] unknown target '${target}'; skipping." ;;
    esac
  done
  # warn (not fail) on collected failures, then log_info "[claude-plugins] Plugins installed."
}
```

Refine the marketplace/install calls with the idempotency guards confirmed in verification (e.g. skip `marketplace add` when `claude plugin marketplace list` already lists it). Rename the loop var away from the `source` builtin (`src`), matching the ai-skills fix.

- [ ] **Step 4: Run the tests to verify they pass.**
- [ ] **Step 5: `shellcheck home/.chezmoitemplates/lib/install/claude-plugins.sh`.**
- [ ] **Step 6: Commit** `feat: add claude-plugins install library` (DOT-43).

---

### Task 2: run script + settings.json declaration

**Files:** Create `home/.chezmoiscripts/darwin/run_onchange_06_install-claude-plugins.sh.tmpl`; Modify `home/dot_claude/settings.json`.

- [ ] **Step 1: Write the run script**, mirroring `run_onchange_09`:

```
#!/usr/bin/env bash
# @file run_onchange_06_install-claude-plugins.sh
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
{{ template "lib/install/claude-plugins.sh" . }}
{{ end }}
```

No local-content hash line is needed (plugins install from external sources, not repo-local files) — unlike ai-skills.

- [ ] **Step 2: Verify the render** for personal (`claude-code`, both plugins) and work (`github-copilot`, both plugins) via `chezmoi execute-template --source home --override-data ...`.

- [ ] **Step 3: Declare marketplaces and enabled plugins in `home/dot_claude/settings.json`** (plain JSON, not templated):

```json
"enabledPlugins": {
  "superwhisper@superwhisper": false,
  "caveman@caveman": true,
  "superpowers@superpowers-dev": true
},
"extraKnownMarketplaces": {
  "superwhisper": { "source": { "source": "github", "repo": "superultrainc/superwhisper-claude-code" } },
  "caveman": { "source": { "source": "github", "repo": "JuliusBrussee/caveman" } },
  "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } }
}
```

- [ ] **Step 4: Commit** `feat: add claude-plugins run_onchange script and settings` (DOT-43).

---

### Task 3: Template render tests

**Files:** Modify `tests/template/darwin-install-scripts.bats`.

- [ ] **Step 1:** Add `PLUGINS_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_06_install-claude-plugins.sh.tmpl"`, an inject-lib assertion (`{{ template "lib/install/claude-plugins.sh" . }}`), a prelude-injection assertion, and render tests:

```bash
@test "personal plugins template targets claude-code and includes both plugins" {
  run render_chezmoi_template "$PLUGINS_TEMPLATE" "$DARWIN_DATA"
  assert_success
  assert_line 'AI_PLUGIN_TARGETS=('
  assert_line --partial '"claude-code"'
  assert_line --partial '"caveman|caveman|JuliusBrussee/caveman"'
  assert_line --partial '"superpowers|superpowers-dev|obra/superpowers"'
  assert_line --partial 'claude_plugins_install_main'
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
  refute_line --partial 'claude_plugins_install_main'
}
```

The existing glob tests (bash shebang, `bash -n` validity) auto-cover the new script.

- [ ] **Step 2:** Run `bats tests/unit/lib/install/claude-plugins.bats tests/template/darwin-install-scripts.bats`; then `mise run check`.
- [ ] **Step 3: Commit** `test: add claude-plugins template render tests` (DOT-43).

---

## Self-Review

- **Spec coverage (Plugins Design):** dual path per target (Task 1), `run_onchange_06` replaces the apm script and gates darwin (Task 2), settings.json declares marketplaces + enabled plugins (Task 2). Covered.
- **Type consistency:** `AI_PLUGIN_TARGETS`, `AI_PLUGINS`, the `<name>|<marketplace>|<source>` contract, and `claude_plugins_install_main` are identical across library, run script, and tests.
- **Open items handed to verification:** `claude plugin` idempotency and list-output formats; the `claude` CLI first-boot PATH caveat (match the Phase-1 hard-fail decision).
- **Out of Phase 2 scope:** MCP delivery, instructions wiring, and the apm dependency-layer teardown are later phases.
