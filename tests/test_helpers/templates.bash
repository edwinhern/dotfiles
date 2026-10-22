#!/usr/bin/env bash
# @file templates.bash
# @brief Shared chezmoi template-rendering helpers for tests/template/*.bats.
#        Provides the source dir and a single render function.
#
# Load AFTER load.bash so DOTFILES_ROOT is already exported:
#   load '../test_helpers/load.bash'
#   load '../test_helpers/templates.bash'

# Chezmoi source directory shared by every template test.
SOURCE_DIR="$DOTFILES_ROOT/home"
export SOURCE_DIR

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
