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
  assert_line 'log_info() {'
  assert_line 'log_warn() {'
  assert_line 'log_error() {'
}

@test "install-apm template uses log_info at the call sites" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_line '  log_info "[apm] Installing globally from ~/.apm/apm.yml (frozen)..."'
  assert_line '  log_info "[apm] Install complete."'
}

@test "install-apm template runs frozen install (no tolerated-failure fallback)" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_line --partial 'apm install --global --frozen'
  refute_line --partial 'apm install --global ||'
}

@test "rendered install-apm script is syntactically valid bash" {
  rendered=$(mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL")
  printf '%s\n' "$rendered" | bash -n
}

@test "rendered install-apm script preserves chezmoi content-hash trigger comments" {
  run mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$DARWIN_DATA" <"$TMPL"
  assert_success
  assert_line --regexp '^# apm\.yml:'
  assert_line --regexp '^# apm data:'
  assert_line --regexp '^# apm mcp template:'
  assert_line --regexp '^# apm lock \(personal\):'
  assert_line --regexp '^# apm lock \(work\):'
  assert_line --regexp '^# agents:'
}
