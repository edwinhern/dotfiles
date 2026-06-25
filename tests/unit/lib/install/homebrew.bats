#!/usr/bin/env bats
# @file tests/unit/lib/install/homebrew.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/homebrew.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/homebrew.sh"

setup() {
  export CURL_ARGS_FILE="$BATS_TEST_TMPDIR/curl-args"
  export HOMEBREW_INSTALL_FILE="$BATS_TEST_TMPDIR/homebrew-installed"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/curl" <<'CURL'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$CURL_ARGS_FILE"
printf '%s\n' 'printf "installed\n" >"$HOMEBREW_INSTALL_FILE"'
CURL
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
}

@test "homebrew_install_main: runs official install script" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && homebrew_install_main"

  assert_success
  assert_line "[homebrew] Installing Homebrew..."
  assert_line "[homebrew] Install complete."
  [ "$(<"$CURL_ARGS_FILE")" = "-fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" ]
  [ "$(<"$HOMEBREW_INSTALL_FILE")" = "installed" ]
}

@test "main: skips installation when brew is already installed" {
  cat >"$BATS_TEST_TMPDIR/bin/brew" <<'BREW'
#!/usr/bin/env bash
exit 0
BREW
  chmod +x "$BATS_TEST_TMPDIR/bin/brew"

  run bash -c "source '$LOG_LIB' && source '$LIB' && main"

  assert_success
  assert_line "[homebrew] Homebrew is already installed, skipping installation."
  [ ! -f "$HOMEBREW_INSTALL_FILE" ]
}
