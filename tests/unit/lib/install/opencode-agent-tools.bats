#!/usr/bin/env bats
# @file tests/unit/lib/install/opencode-agent-tools.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/opencode-agent-tools.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
TOOLS_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/opencode-agent-tools.sh"

setup() {
  AGENTS_DIR="$BATS_TEST_TMPDIR/agents"
  mkdir -p "$AGENTS_DIR"
}

@test "normalize_dir: converts PascalCase array to lowercase map" {
  cat >"$AGENTS_DIR/cavecrew-investigator.md" <<'MD'
---
name: cavecrew-investigator
description: read-only locator
tools: [Read, Grep, Glob, Bash]
model: haiku
---
body content here
MD

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"

  assert_success
  assert_line --partial "rewrote cavecrew-investigator.md"
  assert_line --partial "1 file(s) updated"

  local expected
  expected='---
name: cavecrew-investigator
description: read-only locator
tools:
  read: true
  grep: true
  glob: true
  bash: true
model: haiku
---
body content here'
  [ "$(<"$AGENTS_DIR/cavecrew-investigator.md")" = "$expected" ]
}

@test "normalize_dir: leaves already-mapped files untouched" {
  cat >"$AGENTS_DIR/already-fixed.md" <<'MD'
---
name: already-fixed
tools:
  read: true
  grep: true
---
body
MD
  local before
  before="$(cat "$AGENTS_DIR/already-fixed.md")"

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"

  assert_success
  assert_line --partial "0 file(s) updated"
  [ "$(<"$AGENTS_DIR/already-fixed.md")" = "$before" ]
}

@test "normalize_dir: ignores tools: arrays appearing in the body" {
  cat >"$AGENTS_DIR/body-mention.md" <<'MD'
---
name: body-mention
description: docs
---
Here is markdown:
tools: [Read, Grep]
That should remain unchanged.
MD
  local before
  before="$(cat "$AGENTS_DIR/body-mention.md")"

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"

  assert_success
  assert_line --partial "0 file(s) updated"
  [ "$(<"$AGENTS_DIR/body-mention.md")" = "$before" ]
}

@test "normalize_dir: missing dir is a no-op" {
  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$BATS_TEST_TMPDIR/does-not-exist'"

  assert_success
  assert_line --partial "No agents dir"
}

@test "normalize_dir: empty dir reports zero updates" {
  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"

  assert_success
  assert_line --partial "0 file(s) updated"
}

@test "normalize_dir: drops empty items and strips quotes" {
  cat >"$AGENTS_DIR/messy.md" <<'MD'
---
name: messy
tools: [ Read , , 'Edit' , "Write" ]
---
MD

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"

  assert_success
  local expected
  expected='---
name: messy
tools:
  read: true
  edit: true
  write: true
---'
  [ "$(<"$AGENTS_DIR/messy.md")" = "$expected" ]
}

@test "normalize_dir: idempotent on repeated runs" {
  cat >"$AGENTS_DIR/idem.md" <<'MD'
---
name: idem
tools: [Read, Bash]
---
MD

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"
  assert_success
  local after_first
  after_first="$(cat "$AGENTS_DIR/idem.md")"

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_dir '$AGENTS_DIR'"
  assert_success
  assert_line --partial "0 file(s) updated"
  [ "$(<"$AGENTS_DIR/idem.md")" = "$after_first" ]
}

@test "normalize_file: returns 1 when nothing to change" {
  cat >"$AGENTS_DIR/nothing.md" <<'MD'
---
name: nothing
---
body
MD

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_file '$AGENTS_DIR/nothing.md'"
  assert_failure
}

@test "normalize_file: returns 0 when file is modified" {
  cat >"$AGENTS_DIR/changed.md" <<'MD'
---
name: changed
tools: [Read]
---
MD

  run bash -c "source '$LOG_LIB' && source '$TOOLS_LIB' && opencode_agent_tools_normalize_file '$AGENTS_DIR/changed.md'"
  assert_success
}
