#!/usr/bin/env bats
# @file tests/unit/lib/common/log.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/common/log.sh.
#        Each test sources the lib in a fresh sub-shell and exercises one
#        function. Stderr-only tests swap fds (`2>&1 >/dev/null`) so bats
#        captures the right stream.

load '../../../test_helpers/load.bash'

LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"

@test "log_info: writes message to stdout with no prefix" {
  run sh -c ". '$LIB' && log_info 'hello'"
  assert_success
  assert_output 'hello'
}

@test "log_info: joins multiple args with a single space" {
  run sh -c ". '$LIB' && log_info hello world"
  assert_success
  assert_output 'hello world'
}

@test "log_info: stays on stdout, not stderr" {
  run sh -c ". '$LIB' && log_info 'on-stdout' 2>/dev/null"
  assert_success
  assert_output 'on-stdout'
}

@test "log_warn: writes 'warn: <msg>' to stderr" {
  run sh -c ". '$LIB' && log_warn 'something' 2>&1 >/dev/null"
  assert_success
  assert_output 'warn: something'
}

@test "log_warn: nothing reaches stdout" {
  run sh -c ". '$LIB' && log_warn 'something' 2>/dev/null"
  assert_success
  assert_output ''
}

@test "log_error: writes 'error: <msg>' to stderr" {
  run sh -c ". '$LIB' && log_error 'fatal' 2>&1 >/dev/null"
  assert_success
  assert_output 'error: fatal'
}

@test "log_error: nothing reaches stdout" {
  run sh -c ". '$LIB' && log_error 'fatal' 2>/dev/null"
  assert_success
  assert_output ''
}

@test "log_*: messages with special characters survive intact" {
  run sh -c ". '$LIB' && log_info 'a [tag] msg with \$dollar and (parens)'"
  assert_success
  assert_output 'a [tag] msg with $dollar and (parens)'
}
