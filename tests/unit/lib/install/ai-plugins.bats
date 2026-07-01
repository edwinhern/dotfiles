#!/usr/bin/env bats
# @file tests/unit/lib/install/ai-plugins.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/ai-plugins.sh.
#        Entries are name|marketplace|source|copilot. Claude installs every
#        entry as a native plugin; Copilot routes on the copilot field
#        (plugin -> copilot CLI, skill -> npx skills add).

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/ai-plugins.sh"

# Representative entries: caveman installs as a Copilot skill, superpowers as a
# native Copilot plugin. Both are native plugins for Claude Code.
CAVEMAN='caveman|caveman|JuliusBrussee/caveman|skill'
SUPERPOWERS='superpowers|superpowers-dev|obra/superpowers|plugin'

setup() {
  export CLAUDE_ARGS_FILE="$BATS_TEST_TMPDIR/claude-args"
  export NPX_ARGS_FILE="$BATS_TEST_TMPDIR/npx-args"
  export COPILOT_ARGS_FILE="$BATS_TEST_TMPDIR/copilot-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
exit "${CLAUDE_EXIT_CODE:-0}"
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  cat >"$BATS_TEST_TMPDIR/bin/npx" <<'NPX'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$NPX_ARGS_FILE"
exit "${NPX_EXIT_CODE:-0}"
NPX
  chmod +x "$BATS_TEST_TMPDIR/bin/npx"

  cat >"$BATS_TEST_TMPDIR/bin/copilot" <<'COPILOT'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$COPILOT_ARGS_FILE"
exit "${COPILOT_EXIT_CODE:-0}"
COPILOT
  chmod +x "$BATS_TEST_TMPDIR/bin/copilot"

  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
}

_run_main() {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && $1 && main"
}

@test "claude-code target adds marketplace and installs each plugin natively" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('$CAVEMAN' '$SUPERPOWERS')"

  assert_success
  assert_line "[ai-plugins] Installing AI plugins..."
  assert_line "[ai-plugins] AI plugins installed."
  assert_line "plugin marketplace add JuliusBrussee/caveman"
  assert_line "plugin install caveman@caveman"
  assert_line "plugin marketplace add obra/superpowers"
  assert_line "plugin install superpowers@superpowers-dev"
  # Claude uses the claude CLI only; copilot/npx are untouched.
  [ ! -s "$NPX_ARGS_FILE" ]
  [ ! -s "$COPILOT_ARGS_FILE" ]
}

@test "github-copilot: a skill-mechanism plugin installs via npx skills" {
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('$CAVEMAN')"

  assert_success
  assert_line "--yes skills add JuliusBrussee/caveman -a github-copilot --global --copy --yes"
  [ ! -s "$CLAUDE_ARGS_FILE" ]
  [ ! -s "$COPILOT_ARGS_FILE" ]
}

@test "github-copilot: a plugin-mechanism plugin installs via the copilot CLI" {
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('$SUPERPOWERS')"

  assert_success
  assert_line "plugin marketplace add obra/superpowers"
  assert_line "plugin install superpowers@superpowers-dev"
  [ ! -s "$NPX_ARGS_FILE" ]
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "github-copilot: routes superpowers to the plugin CLI and caveman to skills" {
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('$CAVEMAN' '$SUPERPOWERS')"

  assert_success
  grep -q "skills add JuliusBrussee/caveman -a github-copilot" "$NPX_ARGS_FILE"
  grep -q "plugin install superpowers@superpowers-dev" "$COPILOT_ARGS_FILE"
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "installs every plugin to each active target with the right mechanism" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code' 'github-copilot') && AI_PLUGINS=('$CAVEMAN' '$SUPERPOWERS')"

  assert_success
  # Claude installs both as native plugins.
  grep -q "plugin install caveman@caveman" "$CLAUDE_ARGS_FILE"
  grep -q "plugin install superpowers@superpowers-dev" "$CLAUDE_ARGS_FILE"
  # Copilot: caveman as a skill, superpowers as a native plugin.
  grep -q "skills add JuliusBrussee/caveman -a github-copilot" "$NPX_ARGS_FILE"
  grep -q "plugin install superpowers@superpowers-dev" "$COPILOT_ARGS_FILE"
}

@test "exits cleanly with no plugins" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=()"

  assert_success
  assert_line "[ai-plugins] No plugins to install."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "exits cleanly with no targets" {
  _run_main "AI_PLUGIN_TARGETS=() && AI_PLUGINS=('$CAVEMAN')"

  assert_success
  assert_line "[ai-plugins] No agent targets; nothing to install."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "skips empty plugin entries" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('$CAVEMAN' '' '$SUPERPOWERS')"

  assert_success
  assert_line "plugin install caveman@caveman"
  assert_line "plugin install superpowers@superpowers-dev"
  [ "$(wc -l <"$CLAUDE_ARGS_FILE")" -eq 4 ]
}

@test "skips empty target entries" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code' '') && AI_PLUGINS=('$CAVEMAN')"

  assert_success
  assert_line "plugin install caveman@caveman"
  [ "$(wc -l <"$CLAUDE_ARGS_FILE")" -eq 2 ]
}

@test "warns but succeeds when a plugin fails" {
  export CLAUDE_EXIT_CODE=1
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('$CAVEMAN')"

  assert_success
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - caveman"
  assert_line "[ai-plugins] AI plugins installed."
}

@test "reports only the plugins that failed" {
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
[[ "$*" == *"obra/superpowers"* ]] && exit 1
exit 0
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('$CAVEMAN' '$SUPERPOWERS')"

  assert_success
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - superpowers"
  refute_line "  - caveman"
}

@test "warns and skips an unknown target" {
  _run_main "AI_PLUGIN_TARGETS=('grok') && AI_PLUGINS=('$CAVEMAN')"

  assert_success
  assert_line "warn: [ai-plugins] unknown target 'grok'; skipping."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
  [ ! -s "$NPX_ARGS_FILE" ]
  [ ! -s "$COPILOT_ARGS_FILE" ]
}

@test "fails when claude is missing for a claude-code target" {
  rm -f "$BATS_TEST_TMPDIR/bin/claude"
  # Drop /usr/bin so a host-installed claude cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('$CAVEMAN')"

  assert_failure 1
  assert_line "error: [ai-plugins] claude CLI not found. Ensure Claude Code is installed."
}

@test "github-copilot: warns but succeeds when npx is missing for a skill plugin" {
  rm -f "$BATS_TEST_TMPDIR/bin/npx"
  # Drop /usr/bin so a host-installed npx cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('$CAVEMAN')"

  assert_success
  assert_line "error: [ai-plugins] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - caveman"
}

@test "github-copilot: warns but succeeds when the copilot CLI is missing for a plugin" {
  rm -f "$BATS_TEST_TMPDIR/bin/copilot"
  # Drop /usr/bin so a host-installed copilot cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('$SUPERPOWERS')"

  assert_success
  assert_line "error: [ai-plugins] copilot CLI not found. Install it (brew install copilot-cli)."
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - superpowers"
}

@test "github-copilot: a missing copilot CLI does not block the skill plugin" {
  # Keep the setup PATH (with /usr/bin) so the npx mock still runs; a copilot
  # cask installs to /opt/homebrew/bin, off this PATH, so removing the mock
  # alone makes `command -v copilot` fail.
  rm -f "$BATS_TEST_TMPDIR/bin/copilot"
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('$CAVEMAN' '$SUPERPOWERS')"

  assert_success
  # caveman still installs as a skill; only superpowers fails.
  assert_line "--yes skills add JuliusBrussee/caveman -a github-copilot --global --copy --yes"
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - superpowers"
  refute_line "  - caveman"
}
