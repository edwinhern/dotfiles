#!/usr/bin/env bats
# @file tests/template/install-apm-script.bats
# @brief Renders home/.chezmoiscripts/darwin/run_onchange_06_install-apm.sh.tmpl
#        via `chezmoi execute-template` and asserts the lib/common/log.sh
#        snippet is injected and the resulting script is syntactically valid
#        bash.

load '../test_helpers/load.bash'

TMPL="$DOTFILES_ROOT/home/.chezmoiscripts/darwin/run_onchange_06_install-apm.sh.tmpl"
SOURCE_DIR="$DOTFILES_ROOT/home"
DARWIN_DATA='{"chezmoi":{"os":"darwin"}}'

@test "install-apm template renders without errors" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
}

@test "rendered install-apm script starts with bash shebang" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  [ "${lines[0]}" = "#!/usr/bin/env bash" ]
}

@test "install-apm template gates library injection to darwin" {
  template_content="$(<"$TMPL")"

  [[ "$template_content" == *'{{ if eq .chezmoi.os "darwin" }}'* ]] || return 1
  [[ "$template_content" == *'{{ template "lib/common/log.sh" . }}'* ]] || return 1
  [[ "$template_content" == *'{{ template "lib/install/apm.sh" . }}'* ]] || return 1
}

@test "install-apm template injects log_info, log_warn, log_error definitions" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_output --partial 'log_info() {'
  assert_output --partial 'log_warn() {'
  assert_output --partial 'log_error() {'
}

@test "install-apm template uses log_info at the call sites" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_output --partial 'log_info "[apm] Installing globally'
  assert_output --partial 'log_info "[apm] Install complete."'
}

@test "install-apm template uses log_warn for the tolerated apm install failure" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_output --partial 'apm install --global || log_warn'
}

@test "rendered install-apm script is syntactically valid bash" {
  rendered=$(mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL")
  printf '%s\n' "$rendered" | bash -n
}

@test "rendered install-apm script preserves chezmoi content-hash trigger comments" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_output --partial '# apm.yml:'
  assert_output --partial '# apm data:'
  assert_output --partial '# apm mcp template:'
  assert_output --partial '# apm.lock.yaml:'
  assert_output --partial '# agents:'
}
