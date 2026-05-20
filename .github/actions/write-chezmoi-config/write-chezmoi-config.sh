#!/usr/bin/env sh
# @file write-chezmoi-config.sh
# @brief Write the CI chezmoi stub config for a given context.
#
# Used by the `.github/actions/write-chezmoi-config` composite action to
# materialize $HOME/.config/chezmoi/chezmoi.yaml on CI runners. Extracted
# into a real script so shellcheck and shfmt cover the logic via scripts/.
#
# @arg $1 string Context: "personal" or "work".

set -eu

context="${1:-}"

case "$context" in
personal)
  personal=true
  work=false
  ;;
work)
  personal=false
  work=true
  ;;
*)
  printf 'Unsupported context: %s\n' "$context" >&2
  exit 1
  ;;
esac

mkdir -p "$HOME/.config/chezmoi"
{
  printf "%s\n" "data:"
  printf "%s\n" "  hostname: ci-runner"
  printf "  personal: %s\n" "$personal"
  printf "  work: %s\n" "$work"
  printf "%s\n" "  git:"
  printf "%s\n" "    name: CI Bot"
  printf "%s\n" "    email: ci@example.com"
} >"$HOME/.config/chezmoi/chezmoi.yaml"
