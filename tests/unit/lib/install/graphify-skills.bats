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
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
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
