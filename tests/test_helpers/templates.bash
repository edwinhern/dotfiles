#!/usr/bin/env bash
# @file templates.bash
# @brief Shared chezmoi template-rendering helpers for tests/template/*.bats.
#        Provides the source dir, the common per-context override-data payloads,
#        and a single render function so individual test files stop redefining
#        their own copies.
#
# Load AFTER load.bash so DOTFILES_ROOT is already exported:
#   load '../test_helpers/load.bash'
#   load '../test_helpers/templates.bash'

# Chezmoi source directory shared by every template test.
SOURCE_DIR="$DOTFILES_ROOT/home"
export SOURCE_DIR

# Per-context override-data payloads passed to `chezmoi execute-template`.
PERSONAL_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'
DARWIN_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
export PERSONAL_DATA WORK_DATA DARWIN_DATA

# @description Render a chezmoi template from SOURCE_DIR.
# @arg $1 string Absolute path to the template file.
# @arg $2 string Optional JSON override-data payload. Omit to render with defaults.
render_chezmoi_template() {
  local template="$1" data="${2:-}"

  if [ -n "$data" ]; then
    mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$data" <"$template"
  else
    mise exec -- chezmoi execute-template --source "$SOURCE_DIR" <"$template"
  fi
}
