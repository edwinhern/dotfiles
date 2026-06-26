#!/usr/bin/env bats
# @file statusline-git.bats
# @brief Exercises the git branch/staged/modified segment and the rate-limit bar
#        in home/dot_claude/statusline-command.sh against a REAL repo. The shared
#        statusline fixtures use a nonexistent current_dir, so `cd "$current_dir"`
#        fails there and this code path is otherwise never reached.

load '../test_helpers/load.bash'

STATUSLINE="$DOTFILES_ROOT/home/dot_claude/statusline-command.sh"

setup() {
  # Real repo on the branch "feature-x" with one staged and one modified file.
  REPO="$BATS_TEST_TMPDIR/myrepo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q -b feature-x
  git -C "$REPO" config user.email "test@example.com"
  git -C "$REPO" config user.name "Test"
  printf 'initial\n' >"$REPO/tracked.txt"
  git -C "$REPO" add tracked.txt
  git -C "$REPO" commit -q -m init
  printf 'changed\n' >>"$REPO/tracked.txt" # tracked.txt modified, unstaged -> ~1
  printf 'new\n' >"$REPO/staged.txt"
  git -C "$REPO" add staged.txt # staged.txt added to index -> +1

  # Payload mirroring Claude Code's runtime contract, pointed at the real repo.
  INPUT="$BATS_TEST_TMPDIR/input.json"
  printf '{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":17},"workspace":{"current_dir":"%s"},"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":1747339200}}}' "$REPO" >"$INPUT"
}

@test "renders branch with staged and modified counts" {
  run sh "$STATUSLINE" <"$INPUT"
  assert_success
  assert_line --partial 'myrepo'
  assert_line --partial 'feature-x'
  assert_line --partial '+1'
  assert_line --partial '~1'
}

@test "renders the rate-limit bar for the given percentage" {
  run sh "$STATUSLINE" <"$INPUT"
  assert_success
  assert_line --partial '5h'
  assert_line --partial '█████░░░░░'
  assert_line --partial '50%'
}
