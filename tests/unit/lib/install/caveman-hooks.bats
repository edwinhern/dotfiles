#!/usr/bin/env bats
# @file tests/unit/lib/install/caveman-hooks.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/caveman-hooks.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/caveman-hooks.sh"

RUNTIME_FILES=(
  caveman-config.js
  caveman-activate.js
  caveman-mode-tracker.js
  caveman-stats.js
  package.json
)

setup() {
  export CAVEMAN_HOOK_SOURCE="$BATS_TEST_TMPDIR/src"
  export CAVEMAN_HOOK_DEST="$BATS_TEST_TMPDIR/dest"
  mkdir -p "$CAVEMAN_HOOK_SOURCE"
  local f
  for f in "${RUNTIME_FILES[@]}"; do
    printf 'content-%s\n' "$f" >"$CAVEMAN_HOOK_SOURCE/$f"
  done
}

run_lib() {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && main"
}

@test "main: copies all runtime files into the dest hooks dir" {
  run_lib

  assert_success
  assert_line "[caveman] caveman hook runtime installed."
  local f
  for f in "${RUNTIME_FILES[@]}"; do
    assert_file_exist "$CAVEMAN_HOOK_DEST/$f"
  done
}

@test "main: warns and succeeds when source dir is absent" {
  rm -rf "$CAVEMAN_HOOK_SOURCE"

  run_lib

  assert_success
  assert_line "warn: [caveman] $CAVEMAN_HOOK_SOURCE not found; run run_onchange_06_install-apm first."
  [ ! -d "$CAVEMAN_HOOK_DEST" ]
}

@test "main: warns about missing runtime files but still succeeds" {
  rm -f "$CAVEMAN_HOOK_SOURCE/caveman-stats.js"

  run_lib

  assert_success
  assert_line "warn: [caveman] 1 runtime file(s) missing from source:"
  assert_line "  - caveman-stats.js"
  assert_line "[caveman] caveman hook runtime installed."
  assert_file_exist "$CAVEMAN_HOOK_DEST/caveman-config.js"
  [ ! -f "$CAVEMAN_HOOK_DEST/caveman-stats.js" ]
}
