#!/usr/bin/env bash
# @file scripts/apm-lib.sh
# @brief Shared helpers to materialize a context's ~/.apm into a temp home.
# @description
#   Sourced by scripts/validate-apm.sh and scripts/refresh-apm-locks.sh.
#   Resolves pinned tool paths before HOME is changed, then applies only the
#   ~/.apm chezmoi target into an isolated temp home without firing run scripts.

set -Eeuo pipefail

# @description Resolve pinned chezmoi and apm binaries. Call before changing HOME,
#   because an isolated HOME breaks mise trust resolution.
# @set CHEZMOI_BIN Absolute path to the pinned chezmoi binary.
# @set APM_BIN Absolute path to the pinned apm binary.
function apm_lib_resolve_bins() {
  CHEZMOI_BIN="$(mise which chezmoi)"
  APM_BIN="$(mise which apm)"
  export CHEZMOI_BIN APM_BIN
}

# @description Materialize ~/.apm for a context into a temp home.
# @arg $1 string Context: personal or work.
# @arg $2 string Temp root for chezmoi state and cache.
# @arg $3 string Temp home directory.
# @arg $4 string Repo root (chezmoi source parent).
function apm_lib_materialize() {
  local context="$1" tmp_root="$2" tmp_home="$3" repo="$4"

  HOME="$tmp_home" "$repo/.github/actions/write-chezmoi-config/write-chezmoi-config.sh" "$context"

  "${CHEZMOI_BIN}" apply \
    --source "$repo/home" \
    --destination "$tmp_home" \
    --config "$tmp_home/.config/chezmoi/chezmoi.yaml" \
    --config-format yaml \
    --persistent-state "$tmp_root/chezmoistate-$context.boltdb" \
    --cache "$tmp_root/cache-$context" \
    --refresh-externals=never \
    --include files,dirs \
    --no-tty \
    "$tmp_home/.apm"
}
