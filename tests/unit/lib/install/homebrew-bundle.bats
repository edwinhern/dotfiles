#!/usr/bin/env bats
# @file tests/unit/lib/install/homebrew-bundle.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/homebrew-bundle.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/homebrew-bundle.sh"

setup() {
  export BREW_ARGS_FILE="$BATS_TEST_TMPDIR/brew-args"
  export BREW_STDIN_FILE="$BATS_TEST_TMPDIR/brew-stdin"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/brew" <<'BREW'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$BREW_ARGS_FILE"

case "$1" in
  update)
    exit "${BREW_UPDATE_EXIT_CODE:-0}"
    ;;
  bundle)
    cat >"$BREW_STDIN_FILE"
    exit "${BREW_BUNDLE_EXIT_CODE:-0}"
    ;;
esac

exit "${BREW_EXIT_CODE:-0}"
BREW
  chmod +x "$BATS_TEST_TMPDIR/bin/brew"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "homebrew_bundle_main: runs brew bundle with rendered Brewfile content" {
  export HOMEBREW_BUNDLE_CONTENT=$'tap "homebrew/core"\nbrew "git"'

  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && homebrew_bundle_main"

  assert_success
  assert_line "[homebrew] Updating Homebrew metadata..."
  assert_line "[homebrew] Running brew bundle..."
  assert_line "[homebrew] Packages installed."
  [ "$(<"$BREW_ARGS_FILE")" = $'update\nbundle --file=/dev/stdin' ]
  [ "$(<"$BREW_STDIN_FILE")" = "$HOMEBREW_BUNDLE_CONTENT" ]
}

@test "homebrew_bundle_main: fails when brew bundle fails" {
  export HOMEBREW_BUNDLE_CONTENT='brew "git"'
  export BREW_BUNDLE_EXIT_CODE=7

  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && homebrew_bundle_main"

  assert_failure 7
  assert_line "[homebrew] Running brew bundle..."
  [ "$(<"$BREW_ARGS_FILE")" = $'update\nbundle --file=/dev/stdin' ]
}
