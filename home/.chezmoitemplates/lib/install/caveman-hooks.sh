#!/usr/bin/env bash
# @file lib/install/caveman-hooks.sh
# @brief Install the caveman persistent-mode hook runtime into ~/.claude/hooks.
# @description
#   apm installs caveman as skills only, so its optional SessionStart and
#   UserPromptSubmit hook runtime is never deployed. This copies that runtime
#   from the apm-pinned package source into ${CLAUDE_CONFIG_DIR:-~/.claude}/hooks
#   so the hooks wired in settings.json can resolve their shared caveman-config
#   dependency. Sourcing from the apm_modules copy keeps the runtime on the same
#   version apm pins. Sourceable from bats tests and injected into chezmoi run
#   scripts via chezmoi template rendering.

set -Eeuo pipefail

CAVEMAN_HOOK_SOURCE="${CAVEMAN_HOOK_SOURCE:-${HOME}/.apm/apm_modules/JuliusBrussee/caveman/src/hooks}"
CAVEMAN_HOOK_DEST="${CAVEMAN_HOOK_DEST:-${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/hooks}"
CAVEMAN_HOOK_FILES=(
  "caveman-config.js"
  "caveman-activate.js"
  "caveman-mode-tracker.js"
  "caveman-stats.js"
  "package.json"
)

#
# @description Copy the caveman hook runtime into the Claude hooks directory.
# @exitcode 0 Runtime copied, or source absent (apm has not installed caveman).
#
function caveman_hooks_install_main() {
  if [[ ! -d "${CAVEMAN_HOOK_SOURCE}" ]]; then
    log_warn "[caveman] ${CAVEMAN_HOOK_SOURCE} not found; run run_onchange_06_install-apm first."
    return 0
  fi

  log_info "[caveman] Installing caveman hook runtime into ${CAVEMAN_HOOK_DEST}..."
  mkdir -p "${CAVEMAN_HOOK_DEST}"

  local file
  local missing=()
  for file in "${CAVEMAN_HOOK_FILES[@]}"; do
    if [[ ! -f "${CAVEMAN_HOOK_SOURCE}/${file}" ]]; then
      missing+=("${file}")
      continue
    fi
    cp -f "${CAVEMAN_HOOK_SOURCE}/${file}" "${CAVEMAN_HOOK_DEST}/${file}"
  done

  if ((${#missing[@]} > 0)); then
    log_warn "[caveman] ${#missing[@]} runtime file(s) missing from source:"
    for file in "${missing[@]}"; do
      printf '  - %s\n' "${file}" >&2
    done
  fi

  log_info "[caveman] caveman hook runtime installed."
}

#
# @description Run the caveman hooks install flow.
#
function main() {
  caveman_hooks_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
