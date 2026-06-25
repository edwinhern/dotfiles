#!/usr/bin/env bash
# @file lib/install/graphify-skills.sh
# @brief Install Graphify agent skills.
# @description
#   Runs `graphify install --platform` for each selected platform. This file is
#   sourceable from bats tests and injected into chezmoi run scripts via chezmoi
#   template rendering.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

#
# @description Check if the Graphify CLI is installed.
#
function is_graphify_installed() {
  command -v graphify >/dev/null 2>&1
}

#
# @description Install Graphify skills for selected platforms.
#
function graphify_skills_install_main() {
  local has_platform=0
  local platform

  for platform in "${GRAPHIFY_PLATFORMS[@]-}"; do
    [[ -z "${platform}" ]] && continue
    has_platform=1
    break
  done

  if ((has_platform == 0)); then
    log_info "[graphify] No Graphify platforms to install."
    return 0
  fi

  if ! is_graphify_installed; then
    log_error "[graphify] graphify not found. Ensure run_onchange_03_install-uv-tools ran successfully."
    return 1
  fi

  log_info "[graphify] Installing Graphify agent skills..."

  for platform in "${GRAPHIFY_PLATFORMS[@]-}"; do
    [[ -z "${platform}" ]] && continue
    graphify install --platform "${platform}"
  done

  log_info "[graphify] Graphify agent skills installed."
}

#
# @description Run the Graphify skills install flow.
#
function main() {
  graphify_skills_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
