#!/usr/bin/env bats
# @file tests/template/apm-lockfile.bats
# @brief apm.lock.yaml.tmpl selects the correct per-context lockfile.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

TMPL="$DOTFILES_ROOT/home/dot_apm/apm.lock.yaml.tmpl"
PERSONAL='{"personal":true,"work":false}'
WORK='{"personal":false,"work":true}'

@test "personal context renders the personal lockfile" {
  personal_first="$(grep -m1 resolved_commit "$DOTFILES_ROOT/home/.chezmoitemplates/apm/apm.lock.personal.yaml")"
  run render_chezmoi_template "$TMPL" "$PERSONAL"
  assert_success
  assert_line --regexp '^lockfile_version'
  assert_line "$personal_first"
}

@test "work context renders the work lockfile" {
  run render_chezmoi_template "$TMPL" "$WORK"
  assert_success
  assert_line --regexp '^lockfile_version'
}
