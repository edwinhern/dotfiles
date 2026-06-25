#!/usr/bin/env bats
# @file tests/unit/lib/install/mise.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/mise.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/mise.sh"

setup() {
  export MISE_ARGS_FILE="$BATS_TEST_TMPDIR/mise-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/mise" <<'MISE'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$MISE_ARGS_FILE"
exit "${MISE_EXIT_CODE:-0}"
MISE
  chmod +x "$BATS_TEST_TMPDIR/bin/mise"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "mise_install_main: runs mise install with yes flag" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && mise_install_main"

  assert_success
  assert_line "[mise] Installing mise tools..."
  assert_line "[mise] Mise tools installed."
  [ "$(<"$MISE_ARGS_FILE")" = "install --yes" ]
}

@test "mise_install_main: fails when mise install fails" {
  export MISE_EXIT_CODE=9

  run bash -c "source '$LOG_LIB' && source '$LIB' && mise_install_main"

  assert_failure 9
  assert_line "[mise] Installing mise tools..."
  [ "$(<"$MISE_ARGS_FILE")" = "install --yes" ]
}
