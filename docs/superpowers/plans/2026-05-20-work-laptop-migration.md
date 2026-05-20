# Work Laptop Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the dotfiles so a work Mac can install the approved work apps and get a work-specific Dock layout while preserving the personal setup.

**Architecture:** Package declarations stay in `home/.chezmoidata/packages.yaml` and are rendered by the existing Homebrew Bundle script. Dock layout logic lives in `home/.chezmoitemplates/lib/darwin/defaults.sh`, with `run_onchange_05_defaults.sh.tmpl` passing a rendered `DOTFILES_CONTEXT` value so the Bash library stays sourceable in unit tests.

**Tech Stack:** chezmoi templates, Homebrew Bundle, Mac App Store `mas`, Bash, Bats, `dockutil`, mise tasks.

---

## File Structure

- Modify `home/.chezmoidata/packages.yaml`: move `mas` to shared formulas, add work casks, and add Be Focused as a work MAS app.
- Modify `tests/template/darwin-install-scripts.bats`: add package-rendering tests for personal and work contexts.
- Modify `home/.chezmoitemplates/lib/darwin/defaults.sh`: add Dock helper functions and personal/work layouts.
- Modify `home/.chezmoiscripts/darwin/run_onchange_05_defaults.sh.tmpl`: render `DOTFILES_CONTEXT` before injecting the defaults library.
- Modify `tests/unit/lib/darwin/defaults.bats`: test Dock helper ordering for personal and work layouts.
- Do not modify `home/dot_config/mise/config.toml.tmpl`.

### Task 1: Work Package Declarations

**Files:**

- Modify: `tests/template/darwin-install-scripts.bats`
- Modify: `home/.chezmoidata/packages.yaml`
- Verify unchanged: `home/dot_config/mise/config.toml.tmpl`

- [ ] **Step 1: Add failing package-rendering tests**

Update `tests/template/darwin-install-scripts.bats` to this shape:

```bash
#!/usr/bin/env bats
# @file tests/template/darwin-install-scripts.bats
# @brief Template rendering tests for Darwin chezmoi install scripts.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
DARWIN_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'
PACKAGE_TEMPLATE="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl"

render_template() {
  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$1"
}

render_template_with_data() {
  local template="$1"
  local data="$2"

  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$data" <"$template"
}

@test "darwin install script templates render with bash shebang" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    run render_template "$template"
    assert_success
    [ "${lines[0]}" = "#!/usr/bin/env bash" ]
  done
}

@test "darwin install script templates inject shell libraries" {
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl" '{{ template "lib/install/homebrew-bundle.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_03_install-mise-tools.sh.tmpl" '{{ template "lib/install/mise.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_04_install-vscode-extensions.sh.tmpl" '{{ template "lib/install/vscode.sh" . }}'
  assert_file_contains "$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_05_defaults.sh.tmpl" '{{ template "lib/darwin/defaults.sh" . }}'
}

@test "rendered darwin install scripts are syntactically valid bash" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/darwin/*.tmpl; do
    rendered="$(render_template "$template")"
    printf '%s\n' "$rendered" | bash -n
  done
}

@test "personal package template keeps personal tools and omits work apps" {
  run render_template_with_data "$PACKAGE_TEMPLATE" "$DARWIN_DATA"

  assert_success
  assert_output --partial 'brew "mas"'
  assert_output --partial 'brew "mise"'
  assert_output --partial 'cask "discord"'
  refute_output --partial 'cask "microsoft-office"'
  refute_output --partial 'cask "microsoft-teams"'
  refute_output --partial 'cask "slack"'
  refute_output --partial 'Be Focused - Pomodoro Timer'
}

@test "work package template renders approved work apps" {
  run render_template_with_data "$PACKAGE_TEMPLATE" "$WORK_DATA"

  assert_success
  assert_output --partial 'brew "mas"'
  assert_output --partial 'cask "microsoft-office"'
  assert_output --partial 'cask "microsoft-teams"'
  assert_output --partial 'cask "slack"'
  assert_output --partial 'mas "Be Focused - Pomodoro Timer", id: 973134470'
  refute_output --partial 'cask "microsoft-outlook"'
  refute_output --partial 'brew "java"'
  refute_output --partial 'brew "gradle"'
  refute_output --partial 'brew "maven"'
  refute_output --partial 'brew "kafka"'
}
```

- [ ] **Step 2: Run the package tests to verify they fail**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`

Expected: FAIL in `work package template renders approved work apps` because `microsoft-office`, `microsoft-teams`, `slack`, and Be Focused are not rendered yet. The personal test may also fail until `mas` is moved to shared.

- [ ] **Step 3: Update package declarations**

Edit `home/.chezmoidata/packages.yaml` so the Homebrew package data is:

```yaml
# packages.yaml
# Single source of truth for all package manager declarations.
# Referenced by run_onchange_ scripts via Chezmoi template data (.packages.*).
#
# Each group under darwin.homebrew has the same shape: {formulas, casks, mas}.
# `shared` always applies; `personal` or `work` is added based on host context.

packages:
  darwin:
    homebrew:
      shared:
        taps:
          - anomalyco/tap # For Opencode
        formulas:
          - dockutil
          - fastfetch
          - gh
          - git-delta
          - mise
          - mas
          - starship
          - tmux
          - ripgrep
          - zoxide
          - fd
          - fzf
          - lazygit
          - neovim
          - tree-sitter-cli
          - imagemagick
          - ghostscript
          - tectonic
          - mermaid-cli
          - anomalyco/tap/opencode
        casks:
          # fonts
          - font-monaspace
          - font-jetbrains-mono-nerd-font
          # apps
          - google-chrome
          - ghostty
          - raycast
          - rectangle
          - superwhisper
          - visual-studio-code
        mas: []

      personal:
        taps: []
        formulas: []
        casks:
          - aldente
          - claude-code
          - cleanshot
          - discord
          - displaylink
          - microsoft-excel
          - synology-drive
        mas:
          - name: Klack
            id: 6446206067

      work:
        taps: []
        formulas: []
        casks:
          - microsoft-office
          - microsoft-teams
          - slack
        mas:
          - name: Be Focused - Pomodoro Timer
            id: 973134470
```

- [ ] **Step 4: Verify mise config was not changed**

Run: `git diff -- home/dot_config/mise/config.toml.tmpl`

Expected: no output.

- [ ] **Step 5: Run the package tests to verify they pass**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`

Expected: PASS, 5 tests.

- [ ] **Step 6: Commit package changes**

```bash
git add tests/template/darwin-install-scripts.bats home/.chezmoidata/packages.yaml
git diff --cached --check
git commit -m "feat: add work laptop packages"
```

### Task 2: Personal and Work Dock Layouts

**Files:**

- Modify: `tests/unit/lib/darwin/defaults.bats`
- Modify: `home/.chezmoitemplates/lib/darwin/defaults.sh`
- Modify: `home/.chezmoiscripts/darwin/run_onchange_05_defaults.sh.tmpl`

- [ ] **Step 1: Add failing Dock helper tests**

Replace `tests/unit/lib/darwin/defaults.bats` with:

```bash
#!/usr/bin/env bats
# @file tests/unit/lib/darwin/defaults.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/darwin/defaults.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/darwin/defaults.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export COMMAND_LOG="$BATS_TEST_TMPDIR/commands"
  export DOCK_APPS_LOG="$BATS_TEST_TMPDIR/dock-apps"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"

  for command_name in defaults osascript killall dockutil open; do
    cat >"$BATS_TEST_TMPDIR/bin/$command_name" <<'COMMAND'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$COMMAND_LOG"
if [[ "$(basename "$0")" == defaults && "${1:-}" == read ]]; then
  exit 1
fi
COMMAND
    chmod +x "$BATS_TEST_TMPDIR/bin/$command_name"
  done

  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

capture_dock_layout() {
  local context="$1"
  bash -c "
    source '$LOG_LIB'
    source '$LIB'
    dock_add_app() { printf '%s\n' \"\$1\" >>'$DOCK_APPS_LOG'; }
    DOTFILES_CONTEXT='$context' dock_apply_layout
  "
}

@test "macos_defaults_main: applies defaults and restarts affected services" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && macos_defaults_main"

  assert_success
  assert_output --partial "[defaults] Applying macOS defaults..."
  assert_output --partial "[defaults] macOS defaults applied."
  assert_file_contains "$COMMAND_LOG" "defaults write NSGlobalDomain AppleShowAllExtensions -bool true"
  assert_file_contains "$COMMAND_LOG" "killall Finder"
  assert_file_contains "$COMMAND_LOG" "dockutil --no-restart --remove all"
  assert_file_contains "$COMMAND_LOG" "open -a Google Chrome --args --make-default-browser"
}

@test "dock_apply_layout: personal layout uses personal communication apps" {
  run capture_dock_layout personal

  assert_success
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Discord.app"
  assert_file_contains "$DOCK_APPS_LOG" "/System/Applications/Mail.app"
  assert_file_contains "$DOCK_APPS_LOG" "$HOME/Applications/Chrome Apps.localized/YouTube Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/System/Applications/Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Outlook.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Teams.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Slack.app"
}

@test "dock_apply_layout: work layout uses work communication apps" {
  run capture_dock_layout work

  assert_success
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Outlook.app"
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Microsoft Teams.app"
  assert_file_contains "$DOCK_APPS_LOG" "/Applications/Slack.app"
  assert_file_contains "$DOCK_APPS_LOG" "$HOME/Applications/Chrome Apps.localized/YouTube Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/Applications/Discord.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/System/Applications/Music.app"
  assert_file_not_contains "$DOCK_APPS_LOG" "/System/Applications/Mail.app"
}
```

- [ ] **Step 2: Run the Dock tests to verify they fail**

Run: `mise exec -- bats tests/unit/lib/darwin/defaults.bats`

Expected: FAIL because `dock_apply_layout` is not defined yet.

- [ ] **Step 3: Implement Dock helpers**

Update `home/.chezmoitemplates/lib/darwin/defaults.sh` by replacing the current hard-coded Dock block with helper functions and calling `dock_configure` from `macos_defaults_main`.

The top-level file should keep the existing Finder, screenshot, browser, and `main` logic. Add these functions before `macos_defaults_main`:

```bash
#
# @description Add an app to the Dock when it exists.
#
function dock_add_app() {
  local app="$1"

  [ -d "${app}" ] && dockutil --no-restart --add "${app}" >/dev/null
}

#
# @description Add the personal Dock app order.
#
function dock_apply_personal_layout() {
  dock_add_app "/System/Applications/Apps.app"
  dock_add_app "/System/Applications/System Settings.app"
  dock_add_app "/System/Applications/Utilities/Activity Monitor.app"
  dock_add_app "/Applications/Google Chrome.app"
  dock_add_app "${HOME}/Applications/Chrome Apps.localized/YouTube Music.app"
  dock_add_app "/Applications/Visual Studio Code.app"
  dock_add_app "/Applications/Ghostty.app"
  dock_add_app "/Applications/Discord.app"
  dock_add_app "/System/Applications/Mail.app"
  dock_add_app "/System/Applications/Notes.app"
  dock_add_app "/System/Applications/Reminders.app"
  dock_add_app "/Applications/superwhisper.app"
}

#
# @description Add the work Dock app order.
#
function dock_apply_work_layout() {
  dock_add_app "/System/Applications/Apps.app"
  dock_add_app "/System/Applications/System Settings.app"
  dock_add_app "/System/Applications/Utilities/Activity Monitor.app"
  dock_add_app "/Applications/Google Chrome.app"
  dock_add_app "${HOME}/Applications/Chrome Apps.localized/YouTube Music.app"
  dock_add_app "/Applications/Visual Studio Code.app"
  dock_add_app "/Applications/Ghostty.app"
  dock_add_app "/Applications/Microsoft Outlook.app"
  dock_add_app "/Applications/Microsoft Teams.app"
  dock_add_app "/Applications/Slack.app"
  dock_add_app "/System/Applications/Notes.app"
  dock_add_app "/System/Applications/Reminders.app"
  dock_add_app "/Applications/superwhisper.app"
}

#
# @description Add the Dock layout for the active dotfiles context.
#
function dock_apply_layout() {
  case "${DOTFILES_CONTEXT:-personal}" in
  work)
    dock_apply_work_layout
    ;;
  *)
    dock_apply_personal_layout
    ;;
  esac
}

#
# @description Configure Dock defaults and app order.
#
function dock_configure() {
  defaults write com.apple.dock orientation -string bottom
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock tilesize -int 42
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-time-modifier -float 0.5
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock show-recents -bool false

  if command -v dockutil >/dev/null 2>&1; then
    dockutil --no-restart --remove all >/dev/null 2>&1 || true
    dock_apply_layout
  else
    log_warn "[defaults] dockutil not found. Run 'brew install dockutil' or rerun 'chezmoi apply'."
  fi

  killall Dock
}
```

Inside `macos_defaults_main`, replace the old Dock defaults and `for app in ...` block with:

```bash
  dock_configure
```

- [ ] **Step 4: Render context for the defaults script**

Update `home/.chezmoiscripts/darwin/run_onchange_05_defaults.sh.tmpl` to:

```bash
#!/usr/bin/env bash

{{ if eq .chezmoi.os "darwin" }}
{{ if .work -}}
export DOTFILES_CONTEXT="work"
{{ else -}}
export DOTFILES_CONTEXT="personal"
{{ end -}}
{{ template "lib/common/log.sh" . }}
{{ template "lib/darwin/defaults.sh" . }}
{{ end }}
```

- [ ] **Step 5: Run the Dock tests to verify they pass**

Run: `mise exec -- bats tests/unit/lib/darwin/defaults.bats`

Expected: PASS, 3 tests.

- [ ] **Step 6: Run template syntax tests**

Run: `mise exec -- bats tests/template/darwin-install-scripts.bats`

Expected: PASS, 5 tests.

- [ ] **Step 7: Commit Dock changes**

```bash
git add tests/unit/lib/darwin/defaults.bats home/.chezmoitemplates/lib/darwin/defaults.sh home/.chezmoiscripts/darwin/run_onchange_05_defaults.sh.tmpl
git diff --cached --check
git commit -m "feat: add context-aware Dock layout"
```

### Task 3: Full Verification

**Files:**

- Verify: all changed files from Tasks 1 and 2
- Verify unchanged: `home/dot_config/mise/config.toml.tmpl`

- [ ] **Step 1: Format changed files**

Run: `mise format`

Expected: formatting completes without errors.

- [ ] **Step 2: Verify no mise config change**

Run: `git diff -- home/dot_config/mise/config.toml.tmpl`

Expected: no output.

- [ ] **Step 3: Run full checks**

Run: `mise check`

Expected: Prettier passes, shellcheck passes, shfmt passes, taplo passes, unit bats tests pass, and template bats tests pass.

- [ ] **Step 4: Render personal package script and inspect key lines**

Run:

```bash
mise exec -- chezmoi execute-template \
  --source home \
  --override-data '{"chezmoi":{"os":"darwin"},"personal":true,"work":false}' \
  < home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl
```

Expected output includes:

```text
brew "mas"
cask "discord"
```

Expected output does not include:

```text
cask "microsoft-office"
cask "microsoft-teams"
cask "slack"
```

- [ ] **Step 5: Render work package script and inspect key lines**

Run:

```bash
mise exec -- chezmoi execute-template \
  --source home \
  --override-data '{"chezmoi":{"os":"darwin"},"personal":false,"work":true}' \
  < home/.chezmoiscripts/darwin/run_onchange_02_install-packages.sh.tmpl
```

Expected output includes:

```text
brew "mas"
cask "microsoft-office"
cask "microsoft-teams"
cask "slack"
mas "Be Focused - Pomodoro Timer", id: 973134470
```

Expected output does not include:

```text
cask "microsoft-outlook"
brew "java"
brew "gradle"
brew "maven"
brew "kafka"
```

- [ ] **Step 6: Commit any formatting-only changes if present**

Run: `git status --short`

If `mise format` changed files not included in Task 1 or 2 commits, inspect them with `git diff`, then commit only intended formatting changes:

```bash
git add <formatted-files>
git diff --cached --check
git commit -m "style: format work migration files"
```

If there are no remaining changes, do not create a commit.
