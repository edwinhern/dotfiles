#!/usr/bin/env bash
# @file load.bash
# @brief Single entry point that bats test files source to pull in companion libs
#        (bats-support, bats-assert, bats-file) and to expose DOTFILES_ROOT.
#
# Usage from a test file at any depth under tests/:
#   load '../test_helpers/load.bash'      # tests/unit/foo.bats
#   load '../../test_helpers/load.bash'   # tests/unit/lib/common/log.bats
#
# Then assertions like `assert_success` and `assert_line` are available.

# Absolute paths to the companion libs. `load` itself resolves relative to
# the caller's test dir, not to this file, so absolute paths are required.
__HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load "$__HELPERS_DIR/bats-support/load"
load "$__HELPERS_DIR/bats-assert/load"
load "$__HELPERS_DIR/bats-file/load"

# Repo root, computed relative to this file so depth of the calling test doesn't matter.
DOTFILES_ROOT="$(cd "$__HELPERS_DIR/../.." && pwd)"
export DOTFILES_ROOT
