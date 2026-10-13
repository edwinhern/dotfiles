#!/usr/bin/env sh
# @file write-chezmoi-config.sh
# @brief Write the CI chezmoi stub config.
#
# Used by the `.github/actions/write-chezmoi-config` composite action to
# materialize $HOME/.config/chezmoi/chezmoi.yaml on CI runners. Extracted
# into a real script so shellcheck and shfmt cover the logic via scripts/.

set -eu

mkdir -p "$HOME/.config/chezmoi"
{
  printf "%s\n" "data:"
  printf "%s\n" "  git:"
  printf "%s\n" "    name: CI Bot"
  printf "%s\n" "    email: ci@example.com"
} >"$HOME/.config/chezmoi/chezmoi.yaml"
