#!/usr/bin/env bash
# @file lib/install/vscode.sh
# @brief Install VS Code extensions.
# @description
#   Installs VS Code extensions from a wrapper-rendered `VSCODE_EXTENSIONS`
#   array. This file is sourceable from bats tests and injected into chezmoi
#   run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description Check if the VS Code CLI is installed.
#
function is_vscode_cli_installed() {
  command -v code >/dev/null 2>&1
}

#
# @description Install configured VS Code extensions.
#
function vscode_install_extensions_main() {
  if ! is_vscode_cli_installed; then
    log_warn "[vscode] VS Code CLI not found. Open VS Code and run: Shell Command: Install 'code' command in PATH"
    return 0
  fi

  log_info "[vscode] Installing VS Code extensions..."

  local failed=()
  local extension
  for extension in "${VSCODE_EXTENSIONS[@]-}"; do
    [[ -z "${extension}" ]] && continue

    if ! code --install-extension "${extension}" --force; then
      failed+=("${extension}")
    fi
  done

  if ((${#failed[@]} > 0)); then
    log_warn "[vscode] ${#failed[@]} extension(s) failed to install:"
    printf '  - %s\n' "${failed[@]}" >&2
  fi

  log_info "[vscode] VS Code extensions installed."
}

#
# @description Run the VS Code extension install flow.
#
function main() {
  vscode_install_extensions_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
