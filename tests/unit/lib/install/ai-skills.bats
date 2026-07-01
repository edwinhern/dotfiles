#!/usr/bin/env bats
# @file tests/unit/lib/install/ai-skills.bats
# @brief Behavior tests for home/.chezmoitemplates/lib/install/ai-skills.sh.

load '../../../test_helpers/load.bash'

LOG_LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/log.sh"
PRELUDE="$DOTFILES_ROOT/home/.chezmoitemplates/lib/common/install-prelude.sh"
LIB="$DOTFILES_ROOT/home/.chezmoitemplates/lib/install/ai-skills.sh"

setup() {
  export NPX_ARGS_FILE="$BATS_TEST_TMPDIR/npx-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/npx" <<'NPX'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$NPX_ARGS_FILE"
exit "${NPX_EXIT_CODE:-0}"
NPX
  chmod +x "$BATS_TEST_TMPDIR/bin/npx"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"

  export AI_LOCAL_SKILLS_DIR="$BATS_TEST_TMPDIR/skills"
  mkdir -p "$AI_LOCAL_SKILLS_DIR"
}

_run_main() {
  run bash -c "source '$LOG_LIB' && source '$PRELUDE' && source '$LIB' && $1 && main"
}

@test "main: installs each skill for a single target" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me' 'blader/humanizer|humanizer')"

  assert_success
  assert_line "[ai-skills] Installing cross-agent skills..."
  assert_line "[ai-skills] Cross-agent skills installed."
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code --global --copy --yes"
  assert_line "--yes skills add blader/humanizer --skill humanizer -a claude-code --global --copy --yes"
}

@test "main: passes one -a flag per target" {
  _run_main "AI_SKILL_TARGETS=('claude-code' 'github-copilot') && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_success
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code -a github-copilot --global --copy --yes"
}

@test "main: applies every target to every skill" {
  _run_main "AI_SKILL_TARGETS=('claude-code' 'github-copilot') && AI_SKILLS=('mattpocock/skills|grill-me' 'blader/humanizer|humanizer')"

  assert_success
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code -a github-copilot --global --copy --yes"
  assert_line "--yes skills add blader/humanizer --skill humanizer -a claude-code -a github-copilot --global --copy --yes"
}

@test "main: skips empty skill entries" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me' '' 'blader/humanizer|humanizer')"

  assert_success
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code --global --copy --yes"
  assert_line "--yes skills add blader/humanizer --skill humanizer -a claude-code --global --copy --yes"
  refute_line --partial "skills add  --skill"
  [ "$(wc -l <"$NPX_ARGS_FILE")" -eq 2 ]
}

@test "main: installs a local skill when its directory exists" {
  mkdir -p "$AI_LOCAL_SKILLS_DIR/typescript"
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('local|typescript')"

  assert_success
  assert_line "--yes skills add $AI_LOCAL_SKILLS_DIR/typescript --skill typescript -a claude-code --global --copy --yes"
}

@test "main: skips a local skill when its directory is missing" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('local|react')"

  assert_success
  assert_line "warn: [ai-skills] local skill 'react' not found at $AI_LOCAL_SKILLS_DIR/react; skipping."
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: installs remote skills around a missing local skill" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me' 'local|missing' 'blader/humanizer|humanizer')"

  assert_success
  assert_line "warn: [ai-skills] local skill 'missing' not found at $AI_LOCAL_SKILLS_DIR/missing; skipping."
  assert_line "--yes skills add mattpocock/skills --skill grill-me -a claude-code --global --copy --yes"
  assert_line "--yes skills add blader/humanizer --skill humanizer -a claude-code --global --copy --yes"
  [ "$(wc -l <"$NPX_ARGS_FILE")" -eq 2 ]
}

@test "main: exits cleanly with no skills" {
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=()"

  assert_success
  assert_line "[ai-skills] No skills to install."
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: exits cleanly with no targets" {
  _run_main "AI_SKILL_TARGETS=() && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_success
  assert_line "[ai-skills] No agent targets; nothing to install."
  [ ! -s "$NPX_ARGS_FILE" ]
}

@test "main: warns but succeeds when a skill fails" {
  export NPX_EXIT_CODE=1
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_success
  assert_line "warn: [ai-skills] 1 skill(s) failed to install:"
  assert_line "  - grill-me"
  assert_line "[ai-skills] Cross-agent skills installed."
}

@test "main: reports only the skills that failed" {
  cat >"$BATS_TEST_TMPDIR/bin/npx" <<'NPX'
#!/usr/bin/env bash
printf '%s\n' "$*" | tee -a "$NPX_ARGS_FILE"
[[ "$*" == *"blader/humanizer"* ]] && exit 1
exit 0
NPX
  chmod +x "$BATS_TEST_TMPDIR/bin/npx"

  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me' 'blader/humanizer|humanizer')"

  assert_success
  assert_line "warn: [ai-skills] 1 skill(s) failed to install:"
  assert_line "  - humanizer"
  refute_line "  - grill-me"
}

@test "main: fails when npx is missing" {
  rm -f "$BATS_TEST_TMPDIR/bin/npx"
  # Drop /usr/bin so a host-installed npx cannot mask the missing-npx path; /bin still provides bash.
  export PATH="$BATS_TEST_TMPDIR/bin:/bin"
  _run_main "AI_SKILL_TARGETS=('claude-code') && AI_SKILLS=('mattpocock/skills|grill-me')"

  assert_failure 1
  assert_line "error: [ai-skills] npx not found. Ensure Node.js is installed (run_onchange_03_install-mise-tools)."
}
