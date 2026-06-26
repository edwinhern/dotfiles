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
  local failed=()

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

    if ! graphify install --platform "${platform}"; then
      failed+=("${platform}")
    fi
  done

  if ((${#failed[@]} > 0)); then
    log_warn "[graphify] ${#failed[@]} platform(s) failed to install:"
    printf '  - %s\n' "${failed[@]}" >&2
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
