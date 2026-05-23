# Post-Merge Cleanup Skill Design

**Status:** Approved for implementation.

**Issue:** [#29](https://github.com/edwinhern/dotfiles/issues/29)

## Goal

Create a repo-local OpenCode skill that verifies post-merge cleanup for `edwinhern/dotfiles` after a PR is merged.

## Location

The skill lives at `.agents/skills/post-merge-cleanup/SKILL.md`.

It is not stored under `home/`, so chezmoi will not apply it to the user's global home config. It is meant only for this repository.

## Trigger

Use the skill when the user says a PR was merged and asks to clean up or verify post-merge state.

The skill needs a PR number from the user, or one clearly inferred from the current branch with `gh pr view`.

## Workflow

The skill verifies these checks with fresh commands:

1. Repository is `edwinhern/dotfiles`.
2. Local checkout has no uncommitted changes before switching branches.
3. Local `main` is checked out and fast-forwarded with `git pull --ff-only`.
4. Requested PR is `MERGED` and has a merge commit SHA.
5. PR links at least one Linear `DOT-*` issue.
6. Each linked Linear issue is fetched with `linear issue query` or `mise exec -- linear`, then checked with `jq`.
7. Linked Linear issues are in a completed workflow state.
8. The latest `CI` workflow run on `main` for the merge commit completed with `success`.
9. Final git status is clean.

## Non-Goals

- Do not choose the next issue.
- Do not merge PRs.
- Do not close issues manually.
- Do not delete branches or worktrees.
- Do not install this under `home/`.

## Verification

Use a recent merged PR, such as `#28`, to verify the command sequence. The skill is complete when it can guide an agent to confirm the PR, linked Linear issue, `main` CI, and clean git state without changing repo files.
