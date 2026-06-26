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

@test "personal context: exits success and writes chezmoi.yaml" {
  run "$SCRIPT" personal
  assert_success
  assert_file_exists "$HOME/.config/chezmoi/chezmoi.yaml"
}

@test "personal context: sets personal=true, work=false" {
  run "$SCRIPT" personal
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_line '  personal: true'
  assert_line '  work: false'
}

@test "work context: sets personal=false, work=true" {
  run "$SCRIPT" work
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_line '  personal: false'
  assert_line '  work: true'
}

@test "rendered yaml includes stub hostname and git identity only" {
  run "$SCRIPT" personal
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_line '  hostname: ci-runner'
  assert_line '    name: CI Bot'
  assert_line '    email: ci@example.com'
}

@test "invalid context: exits non-zero with error message on stderr" {
  run "$SCRIPT" garbage
  assert_failure
  assert_line 'Unsupported context: garbage'
}

@test "missing context argument: exits non-zero" {
  run "$SCRIPT"
  assert_failure
}

@test "running twice in same HOME: second invocation overwrites cleanly" {
  run "$SCRIPT" personal
  assert_success
  run "$SCRIPT" work
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_line '  work: true'
  refute_line '  personal: true'
}
