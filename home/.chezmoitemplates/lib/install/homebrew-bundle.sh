#!/usr/bin/env bash
# @file lib/install/homebrew-bundle.sh
# @brief Install Homebrew packages from rendered Brewfile content.
# @description
#   Runs `brew bundle --file=/dev/stdin` using Brewfile content rendered by a
#   chezmoi script wrapper. This file is sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description Install packages from rendered Brewfile content.
#
function homebrew_bundle_main() {
  require_command brew "Ensure run_once_01_install-homebrew ran successfully." || return 1

  log_info "[homebrew] Updating Homebrew metadata..."
  brew update

  log_info "[homebrew] Running brew bundle..."
  printf '%s\n' "${HOMEBREW_BUNDLE_CONTENT:-}" | brew bundle --file=/dev/stdin
  log_info "[homebrew] Packages installed."
}

#
# @description Run the Homebrew package install flow.
#
function main() {
  homebrew_bundle_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # When run directly, pull in the shared libraries that chezmoi otherwise
  # concatenates ahead of this file.
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  # shellcheck source=/dev/null
  command -v require_command >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/install-prelude.sh"
  main
fi
