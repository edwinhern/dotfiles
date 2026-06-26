#!/usr/bin/env bats
# @file tests/unit/scripts/refresh-apm-locks.bats
# @brief Behavior tests for scripts/refresh-apm-locks.sh lockfile refresh flow.
#        Stubs mise, chezmoi, apm, and prettier on PATH and runs an isolated
#        copy of the script so the committed lockfiles are never touched.

load '../../test_helpers/load.bash'

setup() {
  export CALL_FILE="$BATS_TEST_TMPDIR/calls"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"

  # mise resolves pinned tool paths to our stubs.
  cat >"$BIN/mise" <<STUB
#!/usr/bin/env bash
echo "mise \$*" >>"$CALL_FILE"
if [ "\$1" = which ]; then echo "$BIN/\$2"; exit 0; fi
exit 0
STUB

  # chezmoi apply only needs to create the target ~/.apm directory.
  cat >"$BIN/chezmoi" <<STUB
#!/usr/bin/env bash
echo "chezmoi \$*" >>"$CALL_FILE"
mkdir -p "\${@: -1}"
exit 0
STUB

  # apm lock --update --global writes the user-scope lockfile under \$HOME/.apm.
  cat >"$BIN/apm" <<STUB
#!/usr/bin/env bash
echo "apm \$*" >>"$CALL_FILE"
mkdir -p "\$HOME/.apm"
printf 'lockfile_version: 1\n# stub lock\n' >"\$HOME/.apm/apm.lock.yaml"
exit 0
STUB

  # prettier records the files it was asked to format.
  cat >"$BIN/prettier" <<STUB
#!/usr/bin/env bash
echo "prettier \$*" >>"$CALL_FILE"
exit 0
STUB

  chmod +x "$BIN"/*
  export PATH="$BIN:$PATH"

  # Isolated repo copy so cp writes lockfiles into the temp tree, never the real repo.
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/scripts" "$REPO/home/.chezmoitemplates/apm" "$REPO/.github/actions/write-chezmoi-config"
  cp "$DOTFILES_ROOT/scripts/refresh-apm-locks.sh" "$REPO/scripts/refresh-apm-locks.sh"
  cp "$DOTFILES_ROOT/scripts/apm-lib.sh" "$REPO/scripts/apm-lib.sh"
  cat >"$REPO/.github/actions/write-chezmoi-config/write-chezmoi-config.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$REPO/.github/actions/write-chezmoi-config/write-chezmoi-config.sh"

  LOCK_DIR="$REPO/home/.chezmoitemplates/apm"
}

@test "personal context writes the personal lockfile and formats it" {
  run bash "$REPO/scripts/refresh-apm-locks.sh" personal
  assert_success
  assert_line --partial "wrote home/.chezmoitemplates/apm/apm.lock.personal.yaml"

  assert_file_exists "$LOCK_DIR/apm.lock.personal.yaml"
  assert_file_contains "$LOCK_DIR/apm.lock.personal.yaml" 'lockfile_version: 1'

  run cat "$CALL_FILE"
  assert_line --partial "prettier --write $LOCK_DIR/apm.lock.personal.yaml"
}

@test "work context writes the work lockfile only" {
  run bash "$REPO/scripts/refresh-apm-locks.sh" work
  assert_success

  assert_file_exists "$LOCK_DIR/apm.lock.work.yaml"
  assert_file_not_exists "$LOCK_DIR/apm.lock.personal.yaml"
}

@test "no arguments refreshes both contexts" {
  run bash "$REPO/scripts/refresh-apm-locks.sh"
  assert_success

  assert_file_exists "$LOCK_DIR/apm.lock.personal.yaml"
  assert_file_exists "$LOCK_DIR/apm.lock.work.yaml"

  run cat "$CALL_FILE"
  assert_line --partial "prettier --write $LOCK_DIR/apm.lock.personal.yaml $LOCK_DIR/apm.lock.work.yaml"
}

@test "rejects an unknown context before writing anything" {
  run bash "$REPO/scripts/refresh-apm-locks.sh" bogus
  assert_failure
  assert_line --partial "Unsupported context: bogus"
  assert_file_not_exists "$LOCK_DIR/apm.lock.bogus.yaml"
}
