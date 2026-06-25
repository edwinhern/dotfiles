#!/usr/bin/env bash
# @file scripts/refresh-apm-locks.sh
# @brief Regenerate committed per-context APM lockfiles.
# @description
#   For each context: materialize ~/.apm in a temp home, run
#   `apm lock --update --global` to re-resolve refs and rewrite apm.lock.yaml,
#   then copy the lockfile back to
#   home/.chezmoitemplates/apm/apm.lock.<context>.yaml. Never touches real HOME.
#   Note: apm 0.21.0 forwards `apm update` to `self-update` (binary updater), so
#   `apm lock --update --global` is the command that rewrites the user-scope
#   lockfile at ~/.apm/apm.lock.yaml.

set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/apm-lib.sh
source "$repo/scripts/apm-lib.sh"

contexts=("$@")
[ "$#" -eq 0 ] && contexts=(personal work)

apm_lib_resolve_bins
PRETTIER_BIN="$(mise which prettier)"
export PRETTIER_BIN

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

written=()

for context in "${contexts[@]}"; do
  tmp_home="$tmp_root/home-$context"
  mkdir -p "$tmp_home"
  apm_lib_materialize "$context" "$tmp_root" "$tmp_home" "$repo"

  HOME="$tmp_home" \
    XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    "${APM_BIN}" lock --update --global

  dest="$repo/home/.chezmoitemplates/apm/apm.lock.$context.yaml"
  cp "$tmp_home/.apm/apm.lock.yaml" "$dest"
  written+=("$dest")
  printf '[refresh] wrote home/.chezmoitemplates/apm/apm.lock.%s.yaml\n' "$context"
done

"${PRETTIER_BIN}" --write "${written[@]}"
printf '[refresh] formatted %d lockfile(s) with prettier\n' "${#written[@]}"
