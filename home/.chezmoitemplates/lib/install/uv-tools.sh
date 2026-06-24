#!/usr/bin/env bash
# @file lib/install/uv-tools.sh
# @brief Install uv-managed command line tools.
# @description
#   Installs tools from a wrapper-rendered `UV_TOOLS` array with
#   `uv tool install --upgrade`. This file is sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

#
# @description Check if uv is installed.
#
function is_uv_installed() {
  command -v uv >/dev/null 2>&1
}

#
# @description Install tools declared in UV_TOOLS.
#
function uv_tools_install_main() {
  log_info "[uv] Installing uv tools..."

  local tool
  for tool in "${UV_TOOLS[@]-}"; do
    [[ -z "${tool}" ]] && continue
    uv tool install --upgrade "${tool}"
  done

  log_info "[uv] uv tools installed."
}

#
# @description Run the uv tool install flow.
#
function main() {
  if ! is_uv_installed; then
    log_error "[uv] uv not found. Ensure run_onchange_03_install-mise-tools ran successfully."
    return 1
  fi

  uv_tools_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
