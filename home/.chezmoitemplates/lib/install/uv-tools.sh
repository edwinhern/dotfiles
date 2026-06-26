#!/usr/bin/env bash
# @file lib/install/uv-tools.sh
# @brief Install uv-managed command line tools.
# @description
#   Installs tools from a wrapper-rendered `UV_TOOLS` array with
#   `uv tool install --upgrade`. This file is sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description Install tools declared in UV_TOOLS.
#
function uv_tools_install_main() {
  log_info "[uv] Installing uv tools..."

  local failed=()
  local tool
  for tool in "${UV_TOOLS[@]-}"; do
    [[ -z "${tool}" ]] && continue

    if ! uv tool install --upgrade "${tool}"; then
      failed+=("${tool}")
    fi
  done

  if ((${#failed[@]} > 0)); then
    log_warn "[uv] ${#failed[@]} tool(s) failed to install:"
    printf '  - %s\n' "${failed[@]}" >&2
  fi

  log_info "[uv] uv tools installed."
}

#
# @description Run the uv tool install flow.
#
function main() {
  require_command uv "Ensure run_onchange_03_install-mise-tools ran successfully." || return 1

  uv_tools_install_main
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
