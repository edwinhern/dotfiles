#!/usr/bin/env bash
# @file lib/install/graphify-skills.sh
# @brief Install Graphify agent skills.
# @description
#   Runs `graphify install --platform` for each selected platform. This file is
#   sourceable from bats tests and injected into chezmoi run scripts via chezmoi
#   template rendering.

set -Eeuo pipefail

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

  require_command graphify "Ensure run_onchange_03_install-uv-tools ran successfully." || return 1

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
