# AI Skills Install (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install cross-agent skills declared in `home/.chezmoidata/ai.yaml` into the active machine's agent targets using the `skills` CLI, driven by a chezmoi run script and a sourceable, tested install library.

**Architecture:** Mirror the existing `graphify-skills` pattern. A sourceable bash library (`lib/install/ai-skills.sh`) runs `npx skills add` per skill. A `run_onchange` chezmoi script resolves the active targets and active skills from `ai.yaml` via the existing `active-group-values` template, renders them into bash arrays, and sources the library. Bats tests stub `npx` and assert the captured arguments.

**Tech Stack:** chezmoi templates, bash, the `skills` CLI (`npx skills`), bats.

**Spec:** `docs/superpowers/specs/2026-06-30-apm-to-claude-marketplace-migration-design.md` (sections: Group and Target Data Model, Skills Design).

**Scope note:** This is Phase 1 of 7. It delivers skills install on its own. The local domain skills (`typescript`, `react`, `testing`) already exist under `home/.chezmoitemplates/skills/`, authored ahead of this phase, so `source: local` skills install normally. The library still skips a `source: local` skill whose directory is absent as a safety net.

---

## File Structure

- Create: `home/.chezmoitemplates/lib/install/ai-skills.sh` — sourceable install library; one responsibility: run `npx skills add` for each selected skill against the target agents.
- Create: `home/.chezmoiscripts/darwin/run_onchange_09_install-ai-skills.sh.tmpl` — chezmoi run script; resolves active targets and skills from `ai.yaml`, renders bash arrays, sources the library.
- Create: `tests/unit/lib/install/ai-skills.bats` — behavior tests for the library, stubbing `npx`.
- Exists (no change): `home/.chezmoidata/ai.yaml` — the manifest.

## Data Contract

The run script passes the library three inputs:

- `AI_SKILL_TARGETS` — bash array of agent ids, e.g. `("claude-code")`. Sourced from `active-group-values` of `.ai.targets`.
- `AI_SKILLS` — bash array of `"<source>|<skill>"` strings, e.g. `("mattpocock/skills|grill-me")`. Sourced from `active-group-values` of `.ai.skills`.
- `AI_LOCAL_SKILLS_DIR` — absolute path to the authored local skills, `{{ .chezmoi.sourceDir }}/.chezmoitemplates/skills`.

The `|` delimiter is safe because skill sources (`owner/repo`, `local`) and skill names contain no `|`.

---

### Task 1: Install library

**Files:**

- Create: `home/.chezmoitemplates/lib/install/ai-skills.sh`
- Test: `tests/unit/lib/install/ai-skills.bats`

- [ ] **Step 1: Write the failing test file**

Create `tests/unit/lib/install/ai-skills.bats`:

```bash
#!/usr/bin/env bats
# @file tests/unit/lib/install/ai-skills.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/ai-skills.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/ai-skills.sh"

setup() {
  export NPX_ARGS_FILE="$BATS_TEST_TMPDIR/npx-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/npx" <<'NPX'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NPX_ARGS_FILE"
exit "${NPX_EXIT_CODE:-0}"
NPX
  chmod +x "$BATS_TEST_TMPDIR/bin/npx"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"

  export AI_LOCAL_SKILLS_DIR="$BATS_TEST_TMPDIR/skills"
  mkdir -p "$AI_LOCAL_SKILLS_DIR"
}

_run_main() {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && $1 && main"
}

@test "main: installs each skill for a single target" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me' 'blader/humanizer|humanizer')"

  assert_success
  assert_line "[ai-skills] Installing cross-agent skills..."
  assert_line "[ai-skills] Cross-agent skills installed."
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code --global --copy --yes"
  assert_line "--yes skills add blader/humanizer --skill humanizer -a claude-code --global --copy --yes"
}

@test "main: passes one -a flag per target" {
  _run_main "AI_SKILL_TARGETS=('claude-code' 'github-copilot') && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_success
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code -a github-copilot --global --copy --yes"
}

@test "main: skips empty skill entries" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me' '' 'blader/humanizer|humanizer')"

  assert_success
  [ "$(wc -l <"$NPX_ARGS_FILE")" -eq 2 ]
}

@test "main: installs a local skill when its directory exists" {
  mkdir -p "$AI_LOCAL_SKILLS_DIR/typescript"
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('local|typescript')"

  assert_success
  assert_line "--yes skills add $AI_LOCAL_SKILLS_DIR/typescript --skill typescript -a claude-code --global --copy --yes"
}

@test "main: skips a local skill when its directory is missing" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('local|react')"

  assert_success
  assert_line "warn: [ai-skills] local skill 'react' not found at $AI_LOCAL_SKILLS_DIR/react; skipping."
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: exits cleanly with no skills" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=()"

  assert_success
  assert_line "[ai-skills] No skills to install."
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: exits cleanly with no targets" {
  _run_main "AI_SKILL_TARGETS=() && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_success
  assert_line "[ai-skills] No agent targets; nothing to install."
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: warns but succeeds when a skill fails" {
  export NPX_EXIT_CODE=1
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_success
  assert_line "warn: [ai-skills] 1 skill(s) failed to install:"
  assert_line "  - grill-me"
  assert_line "[ai-skills] Cross-agent skills installed."
}

@test "main: fails when npx is missing" {
  rm -f "$BATS_TEST_TMPDIR/bin/npx"
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_failure 1
  assert_line "error: [ai-skills] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats tests/unit/lib/install/ai-skills.bats`
Expected: FAIL — the library file does not exist, so sourcing `$LIB` errors.

- [ ] **Step 3: Write the install library**

Create `home/.chezmoitemplates/lib/install/ai-skills.sh`:

```bash
#!/usr/bin/env bash
# @file lib/install/ai-skills.sh
# @brief Install cross-agent skills with the skills CLI.
# @description
#   Runs `npx skills add` for each selected skill against the active agent
#   targets. Local skill sources resolve under AI_LOCAL_SKILLS_DIR and are
#   skipped when their directory is absent. Sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description Install each selected skill for the active agent targets.
# @exitcode 0 Skills installed, or nothing to do.
# @exitcode 1 npx is not available.
#
function ai_skills_install_main() {
  local has_skill=0
  local entry
  for entry in "${AI_SKILLS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    has_skill=1
    break
  done

  if ((has_skill == 0)); then
    log_info "[ai-skills] No skills to install."
    return 0
  fi

  local -a target_flags=()
  local target
  for target in "${AI_SKILL_TARGETS[@]-}"; do
    [[ -z "${target}" ]] && continue
    target_flags+=("-a" "${target}")
  done

  if ((${#target_flags[@]} == 0)); then
    log_info "[ai-skills] No agent targets; nothing to install."
    return 0
  fi

  require_command npx "Ensure Node.js is installed (run_onchange_03_install-mise-tools)." || return 1

  log_info "[ai-skills] Installing cross-agent skills..."

  local source skill add_source
  local failed=()
  for entry in "${AI_SKILLS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    source="${entry%%|*}"
    skill="${entry##*|}"

    if [[ "${source}" == "local" ]]; then
      add_source="${AI_LOCAL_SKILLS_DIR:?AI_LOCAL_SKILLS_DIR must be set}/${skill}"
      if [[ ! -d "${add_source}" ]]; then
        log_warn "[ai-skills] local skill '${skill}' not found at ${add_source}; skipping."
        continue
      fi
    else
      add_source="${source}"
    fi

    if ! npx --yes skills add "${add_source}" --skill "${skill}" "${target_flags[@]}" --global --copy --yes; then
      failed+=("${skill}")
    fi
  done

  if ((${#failed[@]} > 0)); then
    log_warn "[ai-skills] ${#failed[@]} skill(s) failed to install:"
    printf '  - %s\n' "${failed[@]}" >&2
  fi

  log_info "[ai-skills] Cross-agent skills installed."
}

#
# @description Run the AI skills install flow.
#
function main() {
  ai_skills_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # When run directly, pull in the shared libraries that chezmoi otherwise
  # concatenates ahead of this file.
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  # shellcheck source=/dev/null
  command -v require_command >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/install-prelude.sh"
  main
fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats tests/unit/lib/install/ai-skills.bats`
Expected: PASS — all nine tests green.

- [ ] **Step 5: Lint the library**

Run: `shellcheck home/.chezmoitemplates/lib/install/ai-skills.sh`
Expected: no output (clean). The `${AI_SKILLS[@]-}` guarded expansion avoids unbound-variable errors under `set -u`.

- [ ] **Step 6: Commit**

```bash
git add home/.chezmoitemplates/lib/install/ai-skills.sh tests/unit/lib/install/ai-skills.bats
git commit -m "feat: DOT-43 add ai-skills install library"
```

---

### Task 2: chezmoi run script

**Files:**

- Create: `home/.chezmoiscripts/darwin/run_onchange_09_install-ai-skills.sh.tmpl`

- [ ] **Step 1: Write the run script**

Create `home/.chezmoiscripts/darwin/run_onchange_09_install-ai-skills.sh.tmpl`:

```bash
#!/usr/bin/env bash
# @file run_onchange_09_install-ai-skills.sh
# @brief Install cross-agent AI skills.
# @description AI data hash: {{ include ".chezmoidata/ai.yaml" | sha256sum }}
{{- $activeTargets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.targets) | fromJson -}}
{{- $activeSkills := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .ai.skills) | fromJson -}}

{{ if and (eq .chezmoi.os "darwin") (gt (len $activeTargets) 0) (gt (len $activeSkills) 0) }}
{{ template "lib/common/log.sh" . }}
{{ template "lib/common/install-prelude.sh" . }}
export AI_LOCAL_SKILLS_DIR="{{ .chezmoi.sourceDir }}/.chezmoitemplates/skills"
AI_SKILL_TARGETS=(
{{ range $activeTargets -}}
  "{{ . }}"
{{ end -}}
)
AI_SKILLS=(
{{ range $activeSkills -}}
  "{{ .source }}|{{ .skill }}"
{{ end -}}
)
{{ template "lib/install/ai-skills.sh" . }}
{{ end }}
```

- [ ] **Step 2: Verify the template renders for a personal machine**

Run: `chezmoi execute-template --init --promptString 'groups=personal' < home/.chezmoiscripts/darwin/run_onchange_09_install-ai-skills.sh.tmpl` (adjust the prompt to match this repo's group-selection variable if different; confirm from `home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl`).
Expected: rendered bash with `AI_SKILL_TARGETS=("claude-code")` and `AI_SKILLS` containing the shared plus personal entries (`mattpocock/skills|grill-me`, ..., `schpet/linear-cli|linear-cli`, `upstash/context7|context7-cli`), and the `lib/install/ai-skills.sh` body inlined.

- [ ] **Step 3: Dry-run apply to confirm no template errors**

Run: `chezmoi apply --dry-run --verbose 2>&1 | rg -A2 'run_onchange_09_install-ai-skills'`
Expected: chezmoi shows the script would run; no template parse errors.

- [ ] **Step 4: Commit**

```bash
git add home/.chezmoiscripts/darwin/run_onchange_09_install-ai-skills.sh.tmpl
git commit -m "feat: DOT-43 add ai-skills run_onchange script"
```

---

### Task 3: Template render test

**Files:**

- Modify: `tests/template/darwin-install-scripts.bats` (add cases; follow the existing structure in that file)

- [ ] **Step 1: Inspect the existing template test structure**

Run: `bats --count tests/template/darwin-install-scripts.bats` and open the file to copy its rendering helper and assertion style (it renders `.tmpl` scripts with a group context and asserts on output).

- [ ] **Step 2: Write failing render tests**

Add two tests mirroring the file's existing pattern. Personal render includes shared plus personal skills against `claude-code`; work render excludes personal-only skills. Use the file's existing template-render helper (do not invent a new one). Example assertions:

```bash
@test "run_onchange_09: personal render targets claude-code and includes shared+personal skills" {
  run render_darwin_script "run_onchange_09_install-ai-skills.sh.tmpl" "personal"
  assert_success
  assert_output --partial 'AI_SKILL_TARGETS=('
  assert_output --partial '"claude-code"'
  assert_output --partial '"mattpocock/skills|grill-me"'
  assert_output --partial '"schpet/linear-cli|linear-cli"'
}

@test "run_onchange_09: work render targets github-copilot and excludes personal skills" {
  run render_darwin_script "run_onchange_09_install-ai-skills.sh.tmpl" "work"
  assert_success
  assert_output --partial '"github-copilot"'
  refute_output --partial 'schpet/linear-cli|linear-cli'
}
```

- [ ] **Step 3: Run to verify they fail, then pass**

Run: `bats tests/template/darwin-install-scripts.bats`
Expected: the two new tests fail until the helper name matches the file's actual helper; adjust the helper call to the real one, then they pass.

- [ ] **Step 4: Run the full unit and template suites**

Run: `bats tests/unit/lib/install/ai-skills.bats tests/template/darwin-install-scripts.bats`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add tests/template/darwin-install-scripts.bats
git commit -m "test: DOT-43 add ai-skills template render tests"
```

---

## Self-Review

- **Spec coverage (Skills Design):** Library runs `npx skills add <source> --skill <skill> -a <target> --global --copy --yes` (Task 1); targets and skills resolve from `ai.yaml` via `active-group-values` (Task 2); local sources skip when absent, deferring Phase 5 (Task 1 test 5). Covered.
- **Placeholder scan:** No TBD/TODO; every step has full code or an exact command with expected output. The one adjustable point (the template test helper name in Task 3) is called out explicitly because it depends on the existing file, and the step says to match the real helper.
- **Type consistency:** `AI_SKILLS`, `AI_SKILL_TARGETS`, `AI_LOCAL_SKILLS_DIR`, `ai_skills_install_main`, and the `<source>|<skill>` contract are identical across the library, the run script, and the tests.
- **Out of Phase 1 scope:** plugins install, MCP delivery, instructions, and apm teardown are later phases. Domain-skill authoring and Copilot commit wiring are already done ahead of this plan.

## Remaining Phases (separate plans)

1. This plan — skills install.
2. Plugins install (`run_onchange_06`, caveman + superpowers dual-path).
3. MCP delivery (`claude mcp add` for Claude; templated `mcp.json`/`mcp-config.json` for Copilot).
4. Instructions (`AGENTS.md` canonical → `CLAUDE.md` + Copilot) and commit-message wiring.
5. Author local domain skills (`typescript`, `react`, `testing`) from `home/.chezmoidata/instructions/`.
6. Organize work and Copilot files.
7. Remove APM and update tests.
