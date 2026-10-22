#!/usr/bin/env bats
# @file tests/template/darwin-install-scripts.bats
# @brief Every chezmoi run script renders and parses as bash.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

@test "run scripts render to valid bash" {
  for template in "$DOTFILES_ROOT"/home/.chezmoiscripts/*.tmpl; do
    run render_chezmoi_template "$template"
    assert_success
    printf '%s\n' "$output" | bash -n
  done
}
