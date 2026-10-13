#!/usr/bin/env bats
# @file tests/unit/write-chezmoi-config.bats
# @brief Behavior tests for the CI helper at
#        .github/actions/write-chezmoi-config/write-chezmoi-config.sh.
#        Each test runs the script with a temp HOME so the produced
#        ~/.config/chezmoi/chezmoi.yaml stays isolated.

load '../test_helpers/load.bash'

SCRIPT="$DOTFILES_ROOT/.github/actions/write-chezmoi-config/write-chezmoi-config.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}

@test "exits success and writes chezmoi.yaml" {
  run "$SCRIPT"
  assert_success
  assert_file_exists "$HOME/.config/chezmoi/chezmoi.yaml"
}

@test "rendered yaml includes git identity only" {
  run "$SCRIPT"
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_line '    name: CI Bot'
  assert_line '    email: ci@example.com'
  refute_line --partial 'personal:'
  refute_line --partial 'work:'
}

@test "running twice in same HOME: second invocation overwrites cleanly" {
  run "$SCRIPT"
  assert_success
  run "$SCRIPT"
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_line '    name: CI Bot'
}
