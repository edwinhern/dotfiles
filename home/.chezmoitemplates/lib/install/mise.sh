#!/usr/bin/env bash
# @file lib/install/mise.sh
# @brief Install mise-managed tools.
# @description
#   Runs `mise install --yes` after chezmoi has rendered the user's mise
#   config. This file is sourceable from bats tests and injected into chezmoi
#   run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description Install tools declared in mise config.
#
function mise_install_main() {
  log_info "[mise] Installing mise tools..."
  mise install --yes
  log_info "[mise] Mise tools installed."
}

#
# @description Run the mise install flow.
#
function main() {
  require_command mise "Ensure run_onchange_02_install-packages ran successfully." || return 1

  mise_install_main
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
