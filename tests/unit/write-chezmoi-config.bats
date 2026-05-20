#!/usr/bin/env bats
# @file tests/unit/write-chezmoi-config.bats
# @brief Behavior tests for the CI helper at
#        .github/actions/write-chezmoi-config/write-chezmoi-config.sh.
#        Each test runs the script with a temp HOME so the produced
#        ~/.config/chezmoi/chezmoi.yaml stays isolated.

load '../test_helpers/load.bash'

SCRIPT="$DOTFILES_ROOT/.github/actions/write-chezmoi-config/write-chezmoi-config.sh"

setup() {
  TMPHOME="$(mktemp -d)"
  export HOME="$TMPHOME"
}

teardown() {
  rm -rf "$TMPHOME"
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
  assert_output --partial 'personal: true'
  assert_output --partial 'work: false'
}

@test "work context: sets personal=false, work=true" {
  run "$SCRIPT" work
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_output --partial 'personal: false'
  assert_output --partial 'work: true'
}

@test "rendered yaml includes stub hostname and git identity only" {
  run "$SCRIPT" personal
  assert_success
  run cat "$HOME/.config/chezmoi/chezmoi.yaml"
  assert_output --partial 'hostname: ci-runner'
  assert_output --partial 'name: CI Bot'
  assert_output --partial 'email: ci@example.com'
  refute_output --partial 'atlassian_resource_url:'
}

@test "invalid context: exits non-zero with error message on stderr" {
  run "$SCRIPT" garbage
  assert_failure
  assert_output --partial 'Unsupported context: garbage'
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
  assert_output --partial 'work: true'
  refute_output --partial 'personal: true'
}
