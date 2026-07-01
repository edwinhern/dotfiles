#!/usr/bin/env bash
# @file lib/install/graphify-skills.sh
# @brief Install Graphify agent skills.
# @description
#   Runs `graphify install --platform` for each selected platform. This file is
#   sourceable from bats tests and injected into chezmoi run scripts via chezmoi
#   template rendering.

set -Eeuo pipefail

#
# @description Install Graphify skills for each selected platform.
# @exitcode 0 Installed, or nothing to do.
# @exitcode 1 The graphify CLI is missing.
#
function graphify_skills_install_main() {
  if ! have_any "${GRAPHIFY_PLATFORMS[@]-}"; then
    log_info "[graphify] No Graphify platforms to install."
    return 0
  fi

  require_command graphify "Ensure run_onchange_03_install-uv-tools ran successfully." || return 1

  log_info "[graphify] Installing Graphify agent skills..."

  local -a failed=()
  local platform
  for platform in "${GRAPHIFY_PLATFORMS[@]-}"; do
    [[ -z "${platform}" ]] && continue
    graphify install --platform "${platform}" || failed+=("${platform}")
  done

  if ((${#failed[@]} > 0)); then
    report_failures graphify "platform(s) failed to install" "${failed[@]}"
  fi

  log_info "[graphify] Graphify agent skills installed."
}

#
# @description Run the Graphify skills install flow.
#
function main() {
  graphify_skills_install_main
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
