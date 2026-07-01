#!/usr/bin/env bash
# @file lib/install/ai-plugins.sh
# @brief Install cross-agent AI plugins for the active agent targets.
# @description
#   Installs each plugin in AI_PLUGINS for every agent in AI_PLUGIN_TARGETS.
#   Claude Code plugins install through the marketplace CLI; GitHub Copilot has
#   no plugin runtime, so the plugin source installs as a skill instead.
#   Sourceable from bats tests and injected into chezmoi run scripts via
#   chezmoi template rendering.

set -Eeuo pipefail

#
# @description Add one plugin's marketplace and install it into Claude Code.
# @arg $1 string Plugin name.
# @arg $2 string Marketplace name.
# @arg $3 string Marketplace source repo.
#
function _ai_plugins_add_to_claude() {
  local name="$1" marketplace="$2" src="$3"
  claude plugin marketplace add "${src}" &&
    claude plugin install "${name}@${marketplace}"
}

#
# @description Install one plugin source into GitHub Copilot as a skill.
# @arg $1 string Marketplace source repo.
#
function _ai_plugins_add_to_copilot() {
  npx --yes skills add "$1" -a github-copilot --global --copy --yes
}

#
# @description Install every plugin for the Claude Code target.
# @exitcode 0 Plugins processed (failures are warned, not fatal).
# @exitcode 1 The claude CLI is missing.
#
function _ai_plugins_for_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    log_error "[ai-plugins] claude CLI not found. Ensure Claude Code is installed."
    return 1
  fi

  local -a failed=()
  local entry name marketplace src rest
  for entry in "${AI_PLUGINS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    name="${entry%%|*}"
    rest="${entry#*|}"
    marketplace="${rest%%|*}"
    src="${rest##*|}"
    _ai_plugins_add_to_claude "${name}" "${marketplace}" "${src}" || failed+=("${name}")
  done

  if ((${#failed[@]} > 0)); then
    report_failures ai-plugins "plugin(s) failed to install" "${failed[@]}"
  fi
}

#
# @description Install every plugin for the GitHub Copilot target.
# @exitcode 0 Plugins processed (failures are warned, not fatal).
# @exitcode 1 npx is missing.
#
function _ai_plugins_for_copilot() {
  if ! command -v npx >/dev/null 2>&1; then
    log_error "[ai-plugins] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
    return 1
  fi

  local -a failed=()
  local entry name src
  for entry in "${AI_PLUGINS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    name="${entry%%|*}"
    src="${entry##*|}"
    _ai_plugins_add_to_copilot "${src}" || failed+=("${name}")
  done

  if ((${#failed[@]} > 0)); then
    report_failures ai-plugins "plugin(s) failed to install" "${failed[@]}"
  fi
}

#
# @description Route one agent target to its installer.
# @arg $1 string Agent target id.
#
function _ai_plugins_for_target() {
  case "$1" in
  claude-code) _ai_plugins_for_claude_code ;;
  github-copilot) _ai_plugins_for_copilot ;;
  *)
    log_warn "[ai-plugins] unknown target '$1'; skipping."
    return 0
    ;;
  esac
}

#
# @description Install the active plugins for each active agent target.
# @exitcode 0 Installed, or nothing to do.
# @exitcode 1 A required CLI is missing for a requested target.
#
function ai_plugins_install_main() {
  if ! have_any "${AI_PLUGINS[@]-}"; then
    log_info "[ai-plugins] No plugins to install."
    return 0
  fi

  local -a targets=()
  local target
  for target in "${AI_PLUGIN_TARGETS[@]-}"; do
    [[ -z "${target}" ]] && continue
    targets+=("${target}")
  done

  if ((${#targets[@]} == 0)); then
    log_info "[ai-plugins] No agent targets; nothing to install."
    return 0
  fi

  log_info "[ai-plugins] Installing AI plugins..."
  for target in "${targets[@]}"; do
    _ai_plugins_for_target "${target}" || return 1
  done
  log_info "[ai-plugins] AI plugins installed."
}

#
# @description Run the AI plugins install flow.
#
function main() {
  ai_plugins_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # When run directly, pull in the shared libraries that chezmoi otherwise
  # concatenates ahead of this file.
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  # shellcheck source=/dev/null
  command -v have_any >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/install-prelude.sh"
  main
fi
