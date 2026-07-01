#!/usr/bin/env bash
# @file lib/install/ai-mcp.sh
# @brief Register cross-agent MCP servers on Claude Code.
# @description
#   Runs `claude mcp add` for each server in AI_MCP, scoped to the user. A
#   `claude mcp get` check keeps the flow idempotent by skipping a server that
#   is already registered. Copilot MCP arrives through rendered config files,
#   so this library targets Claude Code only. Sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description True when AI_MCP holds at least one non-empty entry.
# @exitcode 0 A server is present.
# @exitcode 1 No servers.
#
function _ai_mcp_have_any() {
  local entry
  for entry in "${AI_MCP[@]-}"; do
    [[ -z "${entry}" ]] && continue
    return 0
  done
  return 1
}

#
# @description Warn about the MCP servers that failed to register.
# @arg $@ string Names of the servers that failed.
#
function _ai_mcp_report_failures() {
  log_warn "[ai-mcp] ${#} server(s) failed to register:"
  printf '  - %s\n' "$@" >&2
}

#
# @description Register each MCP server on Claude Code, skipping existing ones.
# @exitcode 0 Registered, or nothing to do.
# @exitcode 1 The claude CLI is missing.
#
function ai_mcp_install_main() {
  if ! _ai_mcp_have_any; then
    log_info "[ai-mcp] No MCP servers to register."
    return 0
  fi

  if ! command -v claude >/dev/null 2>&1; then
    log_error "[ai-mcp] claude CLI not found. Ensure Claude Code is installed."
    return 1
  fi

  log_info "[ai-mcp] Registering MCP servers..."

  local -a failed=()
  local entry name transport url rest
  for entry in "${AI_MCP[@]-}"; do
    [[ -z "${entry}" ]] && continue
    name="${entry%%|*}"
    rest="${entry#*|}"
    transport="${rest%%|*}"
    url="${rest##*|}"

    if claude mcp get "${name}" >/dev/null 2>&1; then
      log_info "[ai-mcp] ${name} already registered; skipping."
      continue
    fi

    claude mcp add --scope user --transport "${transport}" "${name}" "${url}" || failed+=("${name}")
  done

  if ((${#failed[@]} > 0)); then
    _ai_mcp_report_failures "${failed[@]}"
  fi

  log_info "[ai-mcp] MCP servers registered."
}

#
# @description Run the AI MCP registration flow.
#
function main() {
  ai_mcp_install_main
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # When run directly, pull in the shared log library that chezmoi otherwise
  # concatenates ahead of this file.
  # shellcheck source=/dev/null
  command -v log_info >/dev/null 2>&1 || source "$(dirname "${BASH_SOURCE[0]}")/../common/log.sh"
  main
fi
