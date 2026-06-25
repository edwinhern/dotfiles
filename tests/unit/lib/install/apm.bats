#!/usr/bin/env bats
# @file tests/unit/lib/install/apm.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/apm.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
APM_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/apm.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export APM_ARGS_FILE="$BATS_TEST_TMPDIR/apm-args"
  export APM_CWD_FILE="$BATS_TEST_TMPDIR/apm-cwd"
  mkdir -p "$HOME/.apm" "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/apm" <<'APM'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$APM_ARGS_FILE"
printf '%s\n' "$PWD" >"$APM_CWD_FILE"
exit "${APM_EXIT_CODE:-0}"
APM
  chmod +x "$BATS_TEST_TMPDIR/bin/apm"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "apm_install_main: runs apm install globally from ~/.apm" {
  run bash -c "source '$LOG_LIB' && source '$APM_LIB' && apm_install_main"

  assert_success
  assert_line "[apm] Installing globally from ~/.apm/apm.yml (frozen)..."
  assert_line "[apm] Install complete."
  [ "$(<"$APM_ARGS_FILE")" = "install --global --frozen" ]
  [ "$(<"$APM_CWD_FILE")" = "$HOME/.apm" ]
}

@test "apm_install_main: warns and completes when apm install fails" {
  export APM_EXIT_CODE=7

  run bash -c "source '$LOG_LIB' && source '$APM_LIB' && apm_install_main"

  assert_success
  assert_line --partial "warn: [apm] apm install --frozen exited non-zero"
  assert_line "[apm] Install complete."
  [ "$(<"$APM_ARGS_FILE")" = "install --global --frozen" ]
}
