#!/usr/bin/env bats
# @file tests/template/apm-lockfile.bats
# @brief apm.lock.yaml.tmpl selects the correct per-context lockfile.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
TMPL="$DOTFILES_ROOT/home/dot_apm/apm.lock.yaml.tmpl"
PERSONAL='{"personal":true,"work":false}'
WORK='{"personal":false,"work":true}'

render() {
  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$1" <"$TMPL"
}

@test "personal context renders the personal lockfile" {
  personal_first="$(grep -m1 resolved_commit "$DOTFILES_ROOT/home/.chezmoitemplates/apm/apm.lock.personal.yaml")"
  run render "$PERSONAL"
  assert_success
  assert_output --partial "lockfile_version"
  assert_output --partial "$personal_first"
}

@test "work context renders the work lockfile" {
  run render "$WORK"
  assert_success
  assert_output --partial "lockfile_version"
}
