#!/usr/bin/env bats
# @file tests/unit/lib/install/uv-tools.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/uv-tools.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/uv-tools.sh"

setup() {
  export UV_ARGS_FILE="$BATS_TEST_TMPDIR/uv-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/uv" <<'UV'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$UV_ARGS_FILE"
if [[ "$*" == *"${UV_FAIL_TOOL:-__never__}"* ]]; then
  exit 8
fi
UV
  chmod +x "$BATS_TEST_TMPDIR/bin/uv"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "uv_tools_install_main: installs each tool with upgrade flag" {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && UV_TOOLS=('graphifyy' 'tavily-cli') && uv_tools_install_main"

  assert_success
  assert_line "[uv] Installing uv tools..."
  assert_line "[uv] uv tools installed."
  [ "$(<"$UV_ARGS_FILE")" = $'tool install --upgrade graphifyy\ntool install --upgrade tavily-cli' ]
}

@test "uv_tools_install_main: skips empty tool entries" {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && UV_TOOLS=('graphifyy' '' 'tavily-cli') && uv_tools_install_main"

  assert_success
  [ "$(<"$UV_ARGS_FILE")" = $'tool install --upgrade graphifyy\ntool install --upgrade tavily-cli' ]
}

@test "uv_tools_install_main: warns but succeeds when a tool fails" {
  export UV_FAIL_TOOL='tavily-cli'

  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && UV_TOOLS=('graphifyy' 'tavily-cli') && uv_tools_install_main"

  assert_success
  assert_line "[uv] Installing uv tools..."
  assert_line "warn: [uv] 1 tool(s) failed to install:"
  assert_line "  - tavily-cli"
  assert_line "[uv] uv tools installed."
  [ "$(<"$UV_ARGS_FILE")" = $'tool install --upgrade graphifyy\ntool install --upgrade tavily-cli' ]
}
