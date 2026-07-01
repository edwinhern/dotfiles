#!/usr/bin/env bats
# @file tests/unit/lib/install/ai-plugins.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/ai-plugins.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/ai-plugins.sh"

setup() {
  export CLAUDE_ARGS_FILE="$BATS_TEST_TMPDIR/claude-args"
  export NPX_ARGS_FILE="$BATS_TEST_TMPDIR/npx-args"
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

  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
}

_run_main() {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && $1 && main"
}

@test "main: claude-code target adds marketplace and installs each plugin" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman' 'superpowers|superpowers-dev|obra/superpowers')"

  assert_success
  assert_line "[ai-plugins] Installing AI plugins..."
  assert_line "[ai-plugins] AI plugins installed."
  assert_line "plugin marketplace add JuliusBrussee/caveman"
  assert_line "plugin install caveman@caveman"
  assert_line "plugin marketplace add obra/superpowers"
  assert_line "plugin install superpowers@superpowers-dev"
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: github-copilot target installs a plugin source as a skill" {
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_success
  assert_line "--yes skills add JuliusBrussee/caveman -a github-copilot --global --copy --yes"
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "main: installs every plugin to each active target" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code' 'github-copilot') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_success
  assert_line "plugin marketplace add JuliusBrussee/caveman"
  assert_line "plugin install caveman@caveman"
  assert_line "--yes skills add JuliusBrussee/caveman -a github-copilot --global --copy --yes"
}

@test "main: exits cleanly with no plugins" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=()"

  assert_success
  assert_line "[ai-plugins] No plugins to install."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "main: exits cleanly with no targets" {
  _run_main "AI_PLUGIN_TARGETS=() && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_success
  assert_line "[ai-plugins] No agent targets; nothing to install."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "main: skips empty plugin entries" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman' '' 'superpowers|superpowers-dev|obra/superpowers')"

  assert_success
  assert_line "plugin install caveman@caveman"
  assert_line "plugin install superpowers@superpowers-dev"
  [ "$(wc -l <"$CLAUDE_ARGS_FILE")" -eq 4 ]
}

@test "main: skips empty target entries" {
  _run_main "AI_PLUGIN_TARGETS=('claude-code' '') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_success
  assert_line "plugin install caveman@caveman"
  [ "$(wc -l <"$CLAUDE_ARGS_FILE")" -eq 2 ]
}

@test "main: warns but succeeds when a plugin fails" {
  export CLAUDE_EXIT_CODE=1
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_success
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - caveman"
  assert_line "[ai-plugins] AI plugins installed."
}

@test "main: reports only the plugins that failed" {
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
[[ "$*" == *"obra/superpowers"* ]] && exit 1
exit 0
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman' 'superpowers|superpowers-dev|obra/superpowers')"

  assert_success
  assert_line "warn: [ai-plugins] 1 plugin(s) failed to install:"
  assert_line "  - superpowers"
  refute_line "  - caveman"
}

@test "main: warns and skips an unknown target" {
  _run_main "AI_PLUGIN_TARGETS=('grok') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_success
  assert_line "warn: [ai-plugins] unknown target 'grok'; skipping."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: fails when claude is missing for a claude-code target" {
  rm -f "$BATS_TEST_TMPDIR/bin/claude"
  # Drop /usr/bin so a host-installed claude cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_PLUGIN_TARGETS=('claude-code') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_failure 1
  assert_line "error: [ai-plugins] claude CLI not found. Ensure Claude Code is installed."
}

@test "main: fails when npx is missing for a github-copilot target" {
  rm -f "$BATS_TEST_TMPDIR/bin/npx"
  # Drop /usr/bin so a host-installed npx cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_PLUGIN_TARGETS=('github-copilot') && AI_PLUGINS=('caveman|caveman|JuliusBrussee/caveman')"

  assert_failure 1
  assert_line "error: [ai-plugins] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
}
