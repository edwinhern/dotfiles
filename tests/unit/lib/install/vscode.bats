#!/usr/bin/env bats
# @file tests/unit/lib/install/vscode.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/vscode.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/vscode.sh"

setup() {
  export CODE_ARGS_FILE="$BATS_TEST_TMPDIR/code-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/code" <<'CODE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODE_ARGS_FILE"
if [[ "$*" == *"${CODE_FAIL_EXTENSION:-__never__}"* ]]; then
  exit 6
fi
CODE
  chmod +x "$BATS_TEST_TMPDIR/bin/code"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "vscode_install_extensions_main: installs each extension with force" {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && VSCODE_EXTENSIONS=('one.ext' 'two.ext') && vscode_install_extensions_main"

  assert_success
  assert_line "[vscode] Installing VS Code extensions..."
  assert_line "[vscode] VS Code extensions installed."
  [ "$(<"$CODE_ARGS_FILE")" = $'--install-extension one.ext --force\n--install-extension two.ext --force' ]
}

@test "vscode_install_extensions_main: warns but succeeds when an extension fails" {
  export CODE_FAIL_EXTENSION='bad.ext'

  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && VSCODE_EXTENSIONS=('good.ext' 'bad.ext') && vscode_install_extensions_main"

  assert_success
  assert_line "warn: [vscode] 1 extension(s) failed to install:"
  assert_line "  - bad.ext"
  assert_line "[vscode] VS Code extensions installed."
}

@test "vscode_install_extensions_main: fails when the VS Code CLI is missing" {
  rm -f "$BATS_TEST_TMPDIR/bin/code"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"

  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && VSCODE_EXTENSIONS=('one.ext') && vscode_install_extensions_main"

  assert_failure 1
  assert_line "error: [code] not found. Open VS Code and run: Shell Command: Install 'code' command in PATH"
}
