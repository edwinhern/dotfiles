---
name: ship-pr
description: Use when a branch is ready to become a pull request and merge, when asked to "ship", "open a PR and merge it", or to watch CI through to completion.
---

# Ship PR

## Overview

One pass from local branch to merged PR. Watch CI with blocking commands; never poll with sleep.

## Steps

1. Preflight: on a feature branch (never main), working tree clean, run the repo's check and test commands (`pnpm check`, `make format`, `mise run test`, or equivalent) before pushing.
2. Push: `git push -u origin HEAD`.
3. PR: `gh pr create --fill`. When the repo uses a tracker, append the ref to the generated body afterwards (`gh pr view --json body -q .body`, then `gh pr edit --body` with `Fixes DOT-123` appended); passing `--body` alongside `--fill` discards the commit-derived body. Check the repo's CLAUDE.md for PR conventions.
4. Arm merge first: `gh pr merge --squash --auto`. Auto-merge fires when checks pass, even if the watch below is interrupted.
5. CI: `gh pr checks --watch`. Never `sleep N && gh ...`; the harness blocks it and `--watch` blocks correctly. For workflow runs use `gh run watch`.
6. Red CI: `gh run view --log-failed`, fix, push, return to step 5. Repeat until green.
7. Verify: `gh pr view --json state,mergedAt` shows `MERGED`, or report that auto-merge is armed with checks still running. Report the PR URL and state honestly.
8. After merge: run the repo's post-merge-cleanup skill if one exists.

## Common mistakes

| Mistake                                          | Fix                                       |
| ------------------------------------------------ | ----------------------------------------- |
| Sleep-based CI polling                           | `gh pr checks --watch` / `gh run watch`   |
| Claiming shipped while auto-merge is still armed | Report the real state                     |
| Force push to fix CI                             | Normal push; force needs user approval    |
| Skipping repo lint before push                   | Preflight is cheaper than a CI round-trip |
