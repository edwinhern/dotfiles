#!/usr/bin/env bats
# @file tests/unit/lib/install/ai-mcp.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/ai-mcp.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/ai-mcp.sh"

setup() {
  export CLAUDE_ARGS_FILE="$BATS_TEST_TMPDIR/claude-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  # Default stub: `mcp get` reports "not found" (exit 1) so `mcp add` runs.
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
[[ "$1 $2" == "mcp get" ]] && exit 1
exit "${CLAUDE_EXIT_CODE:-0}"
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
}

_run_main() {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && $1 && main"
}

@test "main: registers each server with user scope and transport" {
  _run_main "AI_MCP=('grep|http|https://mcp.grep.app' 'tavily|http|https://mcp.tavily.com/mcp/')"

  assert_success
  assert_line "[ai-mcp] Registering MCP servers..."
  assert_line "[ai-mcp] MCP servers registered."
  assert_line "mcp add --scope user --transport http grep https://mcp.grep.app"
  assert_line "mcp add --scope user --transport http tavily https://mcp.tavily.com/mcp/"
}

@test "main: skips a server that is already registered" {
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
# grep already exists; tavily does not.
[[ "$1 $2" == "mcp get" && "$3" == "grep" ]] && exit 0
[[ "$1 $2" == "mcp get" ]] && exit 1
exit 0
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  _run_main "AI_MCP=('grep|http|https://mcp.grep.app' 'tavily|http|https://mcp.tavily.com/mcp/')"

  assert_success
  assert_line "[ai-mcp] grep already registered; skipping."
  refute_line "mcp add --scope user --transport http grep https://mcp.grep.app"
  assert_line "mcp add --scope user --transport http tavily https://mcp.tavily.com/mcp/"
}

@test "main: exits cleanly with no servers" {
  _run_main "AI_MCP=()"

  assert_success
  assert_line "[ai-mcp] No MCP servers to register."
  [ ! -s "$CLAUDE_ARGS_FILE" ]
}

@test "main: skips empty server entries" {
  _run_main "AI_MCP=('grep|http|https://mcp.grep.app' '' 'jira|http|https://mcp.atlassian.com/v1/mcp')"

  assert_success
  assert_line "mcp add --scope user --transport http grep https://mcp.grep.app"
  assert_line "mcp add --scope user --transport http jira https://mcp.atlassian.com/v1/mcp"
}

@test "main: warns but succeeds when a server fails to register" {
  cat >"$BATS_TEST_TMPDIR/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$CLAUDE_ARGS_FILE"
[[ "$1 $2" == "mcp get" ]] && exit 1
[[ "$1 $2" == "mcp add" ]] && exit 1
exit 0
CLAUDE
  chmod +x "$BATS_TEST_TMPDIR/bin/claude"

  _run_main "AI_MCP=('grep|http|https://mcp.grep.app')"

  assert_success
  assert_line "warn: [ai-mcp] 1 server(s) failed to register:"
  assert_line "  - grep"
  assert_line "[ai-mcp] MCP servers registered."
}

@test "main: fails when claude is missing" {
  rm -f "$BATS_TEST_TMPDIR/bin/claude"
  # Drop /usr/bin so a host-installed claude cannot mask the missing path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_MCP=('grep|http|https://mcp.grep.app')"

  assert_failure 1
  assert_line "error: [ai-mcp] claude CLI not found. Ensure Claude Code is installed."
}
