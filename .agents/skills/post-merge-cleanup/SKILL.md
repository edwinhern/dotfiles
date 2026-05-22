---
name: post-merge-cleanup
description: Use after a pull request has been merged in edwinhern/dotfiles to verify local main is fast-forwarded, the PR is merged, linked Linear DOT issues are Done, latest main CI passed, and git status is clean. Use when the user says a PR merged, asks to clean up after merge, or asks to verify post-merge state.
---

# Post-Merge Cleanup

Use this skill only in `edwinhern/dotfiles` after a PR has already been merged.

## Required Input

Use a PR number from the user, such as `#28` or `28`.

If the user does not give a PR number, infer it only when `gh pr view --json number` clearly resolves the current branch to one PR. If it cannot be inferred, ask one short question for the PR number.

## Scope

- Verify post-merge state with fresh commands.
- Switch local checkout to `main` and fast-forward it.
- Confirm the merged PR references one or more Linear `DOT-*` issues.
- Confirm each linked Linear issue is `Done` or another completed workflow state.
- Confirm the latest `main` CI for the merge commit passed.
- Confirm the final git status is clean.

Do not choose the next issue. Do not merge PRs, close issues, delete branches, delete worktrees, or change Linear issue state during cleanup.

## Workflow

1. Verify repository identity:
   Run `gh repo view --json nameWithOwner -q .nameWithOwner`.
   Continue only if it returns `edwinhern/dotfiles`.

2. Check for local changes:
   Run `git status --short --branch`.
   If there are modified, staged, or untracked files, stop and report them before switching branches.

3. Sync `main`:
   Run `git switch main`.
   Run `git pull --ff-only`.

4. Verify the PR:
   Run `gh pr view <PR> --repo edwinhern/dotfiles --json number,title,state,mergedAt,mergeCommit,headRefName,body,url`.
   Require `state` to be `MERGED` and `mergeCommit.oid` to be present.

5. Extract Linear issue IDs:
   Run `gh pr view <PR> --repo edwinhern/dotfiles --json title,headRefName,body -q '[.headRefName,.title,.body] | join("\n")' | rg -o 'DOT-[0-9]+' | sort -u`.
   If no `DOT-*` issue ID is found, report that the PR did not link a Linear issue and stop.

6. Verify each Linear issue:
   Linear CLI is intentionally installed only on personal hosts. If neither `linear` nor `mise exec -- linear` is available, report the verified GitHub/local checks and ask the user to rerun this cleanup from a personal host.

   Run the command below with the extracted issue IDs as arguments, for example `bash -s DOT-7 <<'BASH'`.

   ```bash
   bash -s DOT-7 <<'BASH'
   set -euo pipefail

   if command -v linear >/dev/null 2>&1; then
     linear_cmd=(linear)
   elif mise exec -- linear --version >/dev/null 2>&1; then
     linear_cmd=(mise exec -- linear)
   else
     printf '%s\n' "Linear CLI unavailable. It is intentionally installed only on personal hosts; rerun cleanup from a personal host." >&2
     exit 1
   fi

   jq --version >/dev/null

   for identifier in "$@"; do
     "${linear_cmd[@]}" issue query \
       --team DOT \
       --search "$identifier" \
       --include-archived \
       --json \
       --limit 10 |
       jq -e --arg id "$identifier" '
         ([.nodes[] | select(.identifier == $id)][0]) as $issue
         | if $issue == null then
             error($id + ": not found")
           else
             "\($issue.identifier): \($issue.state.name) (\($issue.state.type)) \($issue.url)",
             if $issue.state.type == "completed" then
               empty
             else
               error($issue.identifier + ": state type is " + $issue.state.type)
             end
           end
       '
   done
   BASH
   ```

   Require each linked Linear issue to print state type `completed`.

7. Verify CI for the merge commit:
   Run `gh run list --repo edwinhern/dotfiles --branch main --commit <MERGE_SHA> --workflow CI --json databaseId,displayTitle,workflowName,status,conclusion,headSha,url --limit 1`.
   Require one `CI` workflow run for `<MERGE_SHA>` and require it to have `status` `completed` and `conclusion` `success`.

8. Verify final local state:
   Run `git status --short --branch`.
   Require the output to show `main` tracking `origin/main` with no file changes.

## Report

Return a concise checklist with evidence:

- `main` sync result and current branch line
- PR number, merged state, merged time, and merge SHA
- Each Linear issue ID, state name, state type, and URL
- CI workflow conclusion and URL
- Final git status

If any check fails, report the failed check, include the command evidence, and stop without claiming cleanup is complete.
