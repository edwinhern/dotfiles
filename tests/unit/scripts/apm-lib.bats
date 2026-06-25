#!/usr/bin/env bats
# @file tests/unit/scripts/apm-lib.bats
# @brief Behavior tests for scripts/apm-lib.sh shared materialization.

load '../../test_helpers/load.bash'

LIB="$DOTFILES_ROOT/scripts/apm-lib.sh"

setup() {
  export ARGS_FILE="$BATS_TEST_TMPDIR/chezmoi-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/chezmoi" <<'CHEZMOI'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ARGS_FILE"
CHEZMOI
  chmod +x "$BATS_TEST_TMPDIR/bin/chezmoi"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cat >"$BATS_TEST_TMPDIR/bin/mise" <<'MISE'
#!/usr/bin/env bash
if [ "$1" = "which" ]; then echo "$BATS_TEST_TMPDIR/bin/$2"; fi
MISE
  chmod +x "$BATS_TEST_TMPDIR/bin/mise"
}

@test "apm_lib_resolve_bins sets CHEZMOI_BIN and APM_BIN before HOME changes" {
  run bash -c "source '$LIB' && apm_lib_resolve_bins && echo \"\$CHEZMOI_BIN|\$APM_BIN\""
  assert_success
  assert_output --partial "/bin/chezmoi|"
  assert_output --partial "/bin/apm"
}

@test "apm_lib_materialize applies only the ~/.apm target with scripts excluded" {
  run bash -c "
    source '$LIB'
    CHEZMOI_BIN='$BATS_TEST_TMPDIR/bin/chezmoi'
    apm_lib_materialize personal '$BATS_TEST_TMPDIR/root' '$BATS_TEST_TMPDIR/home' '$DOTFILES_ROOT'
  "
  assert_success
  run cat "$ARGS_FILE"
  assert_output --partial "apply"
  assert_output --partial "--include files,dirs"
  assert_output --partial "/home/.apm"
  refute_output --partial "scripts"
}
