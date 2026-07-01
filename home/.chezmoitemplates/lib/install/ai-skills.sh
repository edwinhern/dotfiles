#!/usr/bin/env bash
# @file lib/install/ai-skills.sh
# @brief Install cross-agent skills with the skills CLI.
# @description
#   Runs `npx skills add` for each selected skill against the active agent
#   targets. Local skill sources resolve under AI_LOCAL_SKILLS_DIR and are
#   skipped when their directory is absent. Sourceable from bats tests and
#   injected into chezmoi run scripts via chezmoi template rendering.

set -Eeuo pipefail

#
# @description True when AI_SKILLS holds at least one non-empty entry.
# @exitcode 0 A skill is present.
# @exitcode 1 No skills.
#
function _ai_skills_have_any() {
  local entry
  for entry in "${AI_SKILLS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    return 0
  done
  return 1
}

#
# @description Resolve a skill's install source, skipping a missing local skill.
# @arg $1 string Source token: a remote repo, or "local".
# @arg $2 string Skill name.
# @stdout The source to hand to `skills add`.
# @exitcode 0 Source resolved.
# @exitcode 1 A local skill directory is missing (warned; caller should skip).
#
function _ai_skills_source() {
  local src="$1" skill="$2"

  if [[ "${src}" != "local" ]]; then
    printf '%s' "${src}"
    return 0
  fi

  local dir="${AI_LOCAL_SKILLS_DIR:?AI_LOCAL_SKILLS_DIR must be set}/${skill}"
  if [[ -d "${dir}" ]]; then
    printf '%s' "${dir}"
    return 0
  fi

  log_warn "[ai-skills] local skill '${skill}' not found at ${dir}; skipping."
  return 1
}

#
# @description Warn about the skills that failed to install.
# @arg $@ string Names of the skills that failed.
#
function _ai_skills_report_failures() {
  log_warn "[ai-skills] ${#} skill(s) failed to install:"
  printf '  - %s\n' "$@" >&2
}

#
# @description Install each selected skill for the active agent targets.
# @exitcode 0 Skills installed, or nothing to do.
# @exitcode 1 npx is not available.
#
function ai_skills_install_main() {
  if ! _ai_skills_have_any; then
    log_info "[ai-skills] No skills to install."
    return 0
  fi

  local -a target_flags=()
  local target
  for target in "${AI_SKILL_TARGETS[@]-}"; do
    [[ -z "${target}" ]] && continue
    target_flags+=("-a" "${target}")
  done

  if ((${#target_flags[@]} == 0)); then
    log_info "[ai-skills] No agent targets; nothing to install."
    return 0
  fi

  if ! command -v npx >/dev/null 2>&1; then
    log_error "[ai-skills] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
    return 1
  fi

  log_info "[ai-skills] Installing cross-agent skills..."

  local -a failed=()
  local entry src skill add_source
  for entry in "${AI_SKILLS[@]-}"; do
    [[ -z "${entry}" ]] && continue
    src="${entry%%|*}"
    skill="${entry##*|}"

    add_source="$(_ai_skills_source "${src}" "${skill}")" || continue
    npx --yes skills add "${add_source}" --skill "${skill}" "${target_flags[@]}" --global --copy --yes || failed+=("${skill}")
  done

  if ((${#failed[@]} > 0)); then
    _ai_skills_report_failures "${failed[@]}"
  fi

  log_info "[ai-skills] Cross-agent skills installed."
}

#
# @description Run the AI skills install flow.
#
function main() {
  ai_skills_install_main
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
