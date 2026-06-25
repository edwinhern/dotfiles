#!/usr/bin/env bash
# @file scripts/validate-apm.sh
# @brief Validate APM reproducibility for one or both contexts in temp homes.
# @description
#   Materializes ~/.apm via chezmoi (manifest + committed lockfile), then runs
#   `apm install --global --frozen` and `apm audit --ci --no-policy` in an
#   isolated temp home. `all` runs both contexts and aggregates results.
# @arg $1 string Context: personal, work, or all (default all).

set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/apm-lib.sh
source "$repo/scripts/apm-lib.sh"

arg="${1:-all}"
case "$arg" in
personal | work) contexts=("$arg") ;;
all) contexts=(personal work) ;;
*)
  printf 'Unsupported context: %s (use personal, work, or all)\n' "$arg" >&2
  exit 1
  ;;
esac

apm_lib_resolve_bins

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# @description Run the frozen install + audit gate for one context.
# @description
#   Called as an `if` condition, so set -e errexit is suspended here. Capture
#   each step's exit code explicitly and fail the context if any step fails,
#   otherwise a failing `apm install --frozen` would be masked by a passing audit.
# @arg $1 string Context.
function validate_context() {
  local context="$1" tmp_home="$tmp_root/home-$1" install_rc audit_rc
  mkdir -p "$tmp_home"
  if ! apm_lib_materialize "$context" "$tmp_root" "$tmp_home" "$repo"; then
    return 1
  fi

  # Run apm from inside the materialized ~/.apm (matches the runtime installer in
  # lib/install/apm.sh) so it operates on the global manifest and lockfile rather
  # than treating the current repo as a local project. Subshell keeps the loop cwd.
  (
    cd "$tmp_home/.apm" &&
      HOME="$tmp_home" \
        XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
        "${APM_BIN}" install --global --frozen --parallel-downloads 0
  )
  install_rc=$?
  (
    cd "$tmp_home/.apm" &&
      HOME="$tmp_home" \
        XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
        "${APM_BIN}" audit --ci --no-policy
  )
  audit_rc=$?

  if [ "$install_rc" -ne 0 ] || [ "$audit_rc" -ne 0 ]; then
    return 1
  fi
  return 0
}

rc=0
for context in "${contexts[@]}"; do
  if validate_context "$context"; then
    printf '%s: PASS\n' "$context"
  else
    printf '%s: FAIL\n' "$context"
    rc=1
  fi
done
exit "$rc"
