#!/usr/bin/env bash
# @file lib/install/apm.sh
# @brief Install APM-managed agent files from the user-scope APM project.
# @description
#   Runs `apm install --global` from `${HOME}/.apm`. This file is sourceable
#   from bats tests and injected into chezmoi run scripts via chezmoi template
#   rendering.

set -Eeuo pipefail

#
# @description Install APM dependencies from `${HOME}/.apm/apm.yml`.
#
function apm_install_main() {
  require_command apm "Ensure run_onchange_03_install-mise-tools ran successfully." || return 1

  log_info "[apm] Installing globally from ~/.apm/apm.yml (frozen)..."
  cd "${HOME}/.apm" || {
    log_error "[apm] ~/.apm not found; run 'chezmoi apply' to materialize it."
    return 1
  }

  apm install --global --frozen || log_warn "[apm] apm install --frozen exited non-zero (lockfile drift or MCP token prompt in non-interactive shell)"

  log_info "[apm] Install complete."
}

#
# @description Run the APM install flow.
#
function main() {
  apm_install_main
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
