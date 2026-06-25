#!/usr/bin/env bats
# @file tests/unit/scripts/validate-apm.bats
# @brief Behavior tests for scripts/validate-apm.sh argument handling and aggregation.

load '../../test_helpers/load.bash'

SCRIPT="$DOTFILES_ROOT/scripts/validate-apm.sh"

setup() {
  export CALL_FILE="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  for t in mise chezmoi apm; do
    cat >"$BATS_TEST_TMPDIR/bin/$t" <<STUB
#!/usr/bin/env bash
echo "$t \$*" >>"$CALL_FILE"
if [ "$t" = mise ] && [ "\$1" = which ]; then echo "$BATS_TEST_TMPDIR/bin/\$2"; exit 0; fi
if [ "$t" = chezmoi ]; then mkdir -p "\${@: -1}"; fi
exit "\${APM_EXIT:-0}"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/$t"
  done
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "all runs both contexts and reports each" {
  run bash "$SCRIPT" all
  assert_success
  assert_output --partial "personal: PASS"
  assert_output --partial "work: PASS"
}

@test "all reports both even when personal fails, exits non-zero" {
  export APM_EXIT=1
  run bash "$SCRIPT" all
  assert_failure
  assert_output --partial "personal: FAIL"
  assert_output --partial "work: FAIL"
}

@test "rejects an unknown context" {
  run bash "$SCRIPT" bogus
  assert_failure
  assert_output --partial "Unsupported context"
}
