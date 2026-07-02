#!/usr/bin/env bats
# @file tests/unit/lib/common/install-prelude.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/common/install-prelude.sh.
#        The prelude is the shared foundation every install library depends on
#        (require_command / have_any / report_failures), so its own edge cases
#        deserve direct coverage rather than only incidental exercise through
#        the install libs. Each test sources log.sh then the prelude in a fresh
#        bash sub-shell (the helpers use bash arrays and [[ ]]).

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"

# @description Source log.sh + the prelude, then run the given shell snippet.
prelude() {
  bash -c "source '$LOG_LIB' && source '$LIB' && $1"
}

# --- require_command -------------------------------------------------------

@test "require_command: succeeds silently when the command is on PATH" {
  run prelude "require_command bash 'should never print'"
  assert_success
  assert_output ''
}

@test "require_command: fails with error + hint on stderr when missing" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && require_command __definitely_not_a_command__ 'brew install it' 2>&1 >/dev/null"
  assert_failure 1
  assert_output 'error: [__definitely_not_a_command__] not found. brew install it'
}

@test "require_command: writes nothing to stdout on failure" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && require_command __definitely_not_a_command__ 'hint' 2>/dev/null"
  assert_failure 1
  assert_output ''
}

# --- have_any --------------------------------------------------------------

@test "have_any: succeeds when a later argument is non-empty" {
  run prelude "have_any '' '' 'present'"
  assert_success
}

@test "have_any: fails when every argument is empty" {
  run prelude "have_any '' '' ''"
  assert_failure 1
}

@test "have_any: fails when called with no arguments" {
  run prelude "have_any"
  assert_failure 1
}

@test "have_any: unset array expanded as \${arr[@]-} is safe and reports empty" {
  # This is the documented calling convention; an unset array must not error
  # under `set -u` and must be treated as "nothing present".
  run prelude "set -u; empty=(); have_any \"\${empty[@]-}\""
  assert_failure 1
}

@test "have_any: populated array with a non-empty entry succeeds" {
  run prelude "items=('' 'pkg'); have_any \"\${items[@]}\""
  assert_success
}

# --- report_failures -------------------------------------------------------

@test "report_failures: prints tag, count, and summary to stderr" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && report_failures uv 'tool(s) failed to install' foo bar 2>&1 >/dev/null"
  assert_success
  assert_line 'warn: [uv] 2 tool(s) failed to install:'
  assert_line '  - foo'
  assert_line '  - bar'
}

@test "report_failures: count reflects only the failed items, not the leading args" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && report_failures apm 'plugin(s) skipped' only-one 2>&1 >/dev/null"
  assert_success
  assert_line 'warn: [apm] 1 plugin(s) skipped:'
  assert_line '  - only-one'
}

@test "report_failures: writes nothing to stdout" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && report_failures tag 'msg' a b c 2>/dev/null"
  assert_success
  assert_output ''
}

@test "report_failures: preserves items containing spaces as single entries" {
  run bash -c "source '$LOG_LIB' && source '$LIB' && report_failures tag 'thing(s) failed' 'name with spaces' 2>&1 >/dev/null"
  assert_success
  assert_line '  - name with spaces'
}

# --- DOTFILES_DEBUG trace toggle -------------------------------------------

@test "DOTFILES_DEBUG unset: sourcing does not enable xtrace" {
  run bash -c "source '$LOG_LIB' && source '$LIB'; case \$- in *x*) echo TRACE_ON;; *) echo TRACE_OFF;; esac"
  assert_success
  assert_output 'TRACE_OFF'
}

@test "DOTFILES_DEBUG set: sourcing enables xtrace" {
  run bash -c "DOTFILES_DEBUG=1; source '$LOG_LIB' && source '$LIB'; case \$- in *x*) echo TRACE_ON;; *) echo TRACE_OFF;; esac" 2>/dev/null
  assert_success
  assert_line 'TRACE_ON'
}
