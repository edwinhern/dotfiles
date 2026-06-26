#!/usr/bin/env bash
# @file lib/common/install-prelude.sh
# @brief Shared prelude for install libraries under lib/install.
# @description
#   Provides the install-time trace toggle and the require_command guard so
#   each install library keeps only its unique work. Depends on lib/common/log.sh
#   for log_error. Sourceable from bats tests and injected into chezmoi run
#   scripts via chezmoi template rendering, after lib/common/log.sh and before
#   the install library.
#
#   Error-handling conventions for install libraries:
#     Missing prerequisite tool: call require_command and return on failure.
#     Per-item install loop: keep going on failure, then warn with a summary.
#     Single critical command: let it fail the script.
#     Standalone run: the self-exec guard sources log.sh and this prelude when
#                     they are not already defined.

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

#
# @description Fail when a required command is absent from PATH.
# @arg $1 Command name to look up.
# @arg $2 Hint shown when the command is missing.
# @exitcode 0 Command is available.
# @exitcode 1 Command is missing.
#
function require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "[$1] not found. $2"
    return 1
  }
}
