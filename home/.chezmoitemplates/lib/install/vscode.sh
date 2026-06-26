#!/usr/bin/env bash
# @file lib/install/vscode.sh
# @brief Install VS Code extensions.
# @description
#   Installs VS Code extensions from a wrapper-rendered `VSCODE_EXTENSIONS`
#   array. This file is sourceable from bats tests and injected into chezmoi
#   run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description Install configured VS Code extensions.
#
function vscode_install_extensions_main() {
  require_command code "Open VS Code and run: Shell Command: Install 'code' command in PATH" || return 1

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
  # When run directly, pull in the shared libraries that chezmoi otherwise
  # concatenates ahead of this file.
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  # shellcheck source=/dev/null
  command -v require_command >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/install-prelude.sh"
  main
fi
