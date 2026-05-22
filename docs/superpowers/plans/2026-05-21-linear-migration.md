# Linear Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish moving `edwinhern/dotfiles` work tracking from GitHub Issues and GitHub Projects to Linear team `dotfiles` (`DOT`).

**Architecture:** Linear becomes the planning source of truth. Root repo guidance explains the workflow for any agent, Linear CLI handles issue reads and updates, and GitHub remains responsible for code review, CI, releases, and PR links.

**Tech Stack:** Markdown, Linear CLI through mise, GitHub CLI `gh`, repo-local agent skills, mise linting.

---

## File Structure

- Modify `AGENTS.md`: replace GitHub Issues and GitHub Project planning guidance with Linear team `dotfiles` (`DOT`) guidance for all repo agents.
- Modify `.agents/skills/post-merge-cleanup/SKILL.md`: keep the existing post-merge cleanup skill but change issue verification from GitHub Issues and GitHub Project status to Linear `DOT-*` issue status.
- Modify `home/dot_config/mise/config.toml.tmpl`: install `npm:@schpet/linear-cli` for personal hosts.
- Modify `tests/template/mise-config.bats`: verify the personal mise config installs Linear CLI.
- Modify Linear workspace data: set native priority and state on imported open Linear issues.
- Modify GitHub remote data: close migrated open GitHub issues with migration comments and close the GitHub Project named `dotfiles` after Linear is verified.

## Shared Rules

- Do not add Linear MCP.
- Install Linear CLI through mise (`npm:@schpet/linear-cli`) for personal hosts when a CLI workflow is required. Do not add a Homebrew tap or formula for Linear.
- Use Linear priority values: `1` = Urgent, `2` = High, `3` = Medium, `4` = Low, `0` = No priority.
- Keep the GitHub Project closed instead of deleting it so prior PR and issue links remain recoverable if needed.

### Task 1: Clean Up Imported Linear Issues

**Files:**

- Read: `docs/superpowers/specs/2026-05-21-linear-migration-design.md`
- Modify: Linear team `dotfiles` (`DOT`) workspace data

- [ ] **Step 1: Confirm Linear CLI is available**

Run:

```bash
linear --version || mise exec -- linear --version
jq --version
```

Expected: prints the Linear CLI version and jq version.

- [ ] **Step 2: Read current states and imported open issues**

Run:

```bash
for id in DOT-5 DOT-6 DOT-7 DOT-9 DOT-10 DOT-11; do
  mise exec -- linear issue query --team DOT --search "$id" --include-archived --json --limit 10 |
    jq -r --arg id "$id" '([.nodes[] | select(.identifier == $id)][0]) | "\(.identifier): priority \(.priority) state \(.state.name) type \(.state.type)"'
done
```

Expected: one team named `dotfiles` with key `DOT`; states include `Backlog` and `In Progress`; issues include `DOT-5`, `DOT-6`, `DOT-7`, `DOT-9`, `DOT-10`, and `DOT-11`.

- [ ] **Step 3: Set native priority and state for imported open issues**

Run:

```bash
mise exec -- linear issue update DOT-7 --priority 2 --state "In Progress"
mise exec -- linear issue update DOT-6 --priority 3 --state Backlog
mise exec -- linear issue update DOT-11 --priority 3 --state Backlog
mise exec -- linear issue update DOT-5 --priority 4 --state Backlog
mise exec -- linear issue update DOT-9 --priority 4 --state Backlog
mise exec -- linear issue update DOT-10 --priority 4 --state Backlog
```

Expected output includes:

```text
DOT-7: priority 2, state In Progress
DOT-6: priority 3, state Backlog
DOT-11: priority 3, state Backlog
DOT-5: priority 4, state Backlog
DOT-9: priority 4, state Backlog
DOT-10: priority 4, state Backlog
```

- [ ] **Step 4: Verify archived completed imported issues are queryable**

Run:

```bash
for id in DOT-8 DOT-12 DOT-13 DOT-14 DOT-15 DOT-16 DOT-17 DOT-18 DOT-19 DOT-20; do
  mise exec -- linear issue query --team DOT --search "$id" --include-archived --json --limit 10 |
    jq -r --arg id "$id" '([.nodes[] | select(.identifier == $id)][0]) | "\(.identifier): state \(.state.name) archived \(.archivedAt != null)"'
done
```

Expected: ten entries for `DOT-8`, `DOT-12`, `DOT-13`, `DOT-14`, `DOT-15`, `DOT-16`, `DOT-17`, `DOT-18`, `DOT-19`, and `DOT-20`, each with `archived: true`.

### Task 2: Update Repo Agent Guidance

**Files:**

- Modify: `AGENTS.md:16-42`
- Read: `home/dot_config/opencode/AGENTS.md.tmpl`
- Read: `home/dot_claude/CLAUDE.md.tmpl`

- [ ] **Step 1: Replace the planning sections in `AGENTS.md`**

Replace the current `## Planning Workflow`, `## Task Selection`, and `## Agent Work Tracking` sections with:

```markdown
## Planning Workflow

- Linear is the source of truth for features, bugs, enhancements, cleanup work, research, and follow-up tasks.
- Use the Linear team `dotfiles` with key `DOT` for this repository.
- Use Linear workflow states: `Backlog`, `Todo`, `In Progress`, `In Review`, and `Done`.
- Treat `Backlog` as the backlog lane and `Todo` as ready but not active.
- Do not use GitHub Issues or GitHub Projects for new work after the Linear cutover.
- Do not use `docs/` as the issue tracker, roadmap, or long-lived backlog.
- Superpowers specs and plans live under `docs/superpowers/` and should be linked from the related Linear issue description or a Linear comment.

## Task Selection

- Use Linear native priority to choose the next task: `High`, then `Medium`, then `Low`.
- Use `Urgent` only for security, broken reproducibility, or a blocked daily workflow that needs immediate attention.
- `High` means security, reproducibility, broken workflow, or work that unlocks important follow-up work.
- `Medium` means useful cleanup, maintenance, or decision work with clear value but no current breakage.
- `Low` means speculative, optional, or only worth doing when current pain appears.
- If priority is missing, set or ask for the priority before implementation starts.
- When priorities tie, prefer security and reproducibility work first, then blockers, then the smallest clear issue.
- Do not add story points unless the user explicitly asks for them.
- When starting work, move the selected Linear issue to `In Progress` and link the relevant Superpowers spec or plan before code changes.

## Agent Work Tracking

- When new work is discovered, create or update a Linear issue instead of adding a backlog item under `docs/`.
- Keep issues small enough to close with one PR or a short linked PR series.
- Link the relevant Superpowers spec or plan from the Linear issue before implementation starts.
- Track active work by moving the Linear issue through the team workflow instead of editing a progress document.
- Link PRs to Linear issues by including the issue ID in the branch, PR title, or PR body.
- Use Linear closing keywords in PR text, such as `Fixes DOT-123`, when merge should move the Linear issue to `Done`.
- If a thought is not ready for an issue, keep it in the current conversation or a Superpowers spec until it becomes actionable.
```

- [ ] **Step 2: Verify templates render the root guidance**

Run:

```bash
rg '{{ template "AGENTS.md" . -}}' home/dot_config/opencode/AGENTS.md.tmpl home/dot_claude/CLAUDE.md.tmpl
```

Expected: both template files match. No template edit is needed because both already render the shared `AGENTS.md` template.

- [ ] **Step 3: Check old active GitHub planning language is gone from `AGENTS.md`**

Run:

```bash
rg 'GitHub Issues are the source|GitHub Project named|dotfiles project `Priority`|Closes #123|Fixes #123' AGENTS.md
```

Expected: no matches. `rg` exits `1` when there are no matches, which is acceptable for this check.

- [ ] **Step 4: Run formatting and lint checks**

Run:

```bash
mise lint
```

Expected: Prettier reports all matched files use Prettier code style and taplo completes without errors.

- [ ] **Step 5: Commit the guidance change if commits are approved for this execution**

Run only when the user has explicitly approved commits:

```bash
git add AGENTS.md
git commit -m "docs: point agents at Linear"
```

Expected: one commit containing only `AGENTS.md`.

### Task 3: Add Linear CLI Tooling

**Files:**

- Modify: `home/dot_config/mise/config.toml.tmpl`
- Modify: `tests/template/mise-config.bats`

- [ ] **Step 1: Install Linear CLI through mise for personal hosts**

Add `"npm:@schpet/linear-cli" = "latest"` to the personal package block in `home/dot_config/mise/config.toml.tmpl`.

- [ ] **Step 2: Keep Linear out of Homebrew package data**

Do not add `schpet/tap`, `schpet/tap/linear`, `linear`, or `schpet/tap/linear` to `home/.chezmoidata/packages.yaml`.

- [ ] **Step 3: Verify mise config renders Linear CLI**

Run:

```bash
mise exec -- bats tests/template/mise-config.bats
```

Expected: the personal mise template test asserts `"npm:@schpet/linear-cli" = "latest"`.

- [ ] **Step 4: Run formatting and lint checks**

Run:

```bash
mise lint
```

Expected: Prettier reports all matched files use Prettier code style and taplo completes without errors.

- [ ] **Step 5: Commit the Linear CLI package change if commits are approved for this execution**

Run only when the user has explicitly approved commits:

```bash
git add home/dot_config/mise/config.toml.tmpl tests/template/mise-config.bats
git commit -m "feat: add Linear CLI package"
```

Expected: one commit containing the mise package and template test.

### Task 4: Update Post-Merge Cleanup Skill

**Files:**

- Modify: `.agents/skills/post-merge-cleanup/SKILL.md`

- [ ] **Step 1: Replace the post-merge cleanup skill content**

Replace `.agents/skills/post-merge-cleanup/SKILL.md` with:

````markdown
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

2. Verify local tools:
   Run `linear --version`.
   If `linear` is not on `PATH`, run `mise exec -- linear --version`.
   Use `linear` for later Linear commands when it works directly. Otherwise use `mise exec -- linear`.
   Run `jq --version`.

3. Check for local changes:
   Run `git status --short --branch`.
   If there are modified, staged, or untracked files, stop and report them before switching branches.

4. Sync `main`:
   Run `git switch main`.
   Run `git pull --ff-only`.

5. Verify the PR:
   Run `gh pr view <PR> --repo edwinhern/dotfiles --json number,title,state,mergedAt,mergeCommit,headRefName,body,url`.
   Require `state` to be `MERGED` and `mergeCommit.oid` to be present.

6. Extract Linear issue IDs:
   Run `gh pr view <PR> --repo edwinhern/dotfiles --json title,headRefName,body -q '[.headRefName,.title,.body] | join("\n")' | rg -o 'DOT-[0-9]+' | sort -u`.
   If no `DOT-*` issue ID is found, report that the PR did not link a Linear issue and stop.

7. Verify each Linear issue:
   Run the command below with the extracted issue IDs as arguments, for example `bash -s DOT-7 <<'BASH'`.

   ```bash
   bash -s DOT-7 <<'BASH'
   set -euo pipefail

   linear_cmd=(linear)
   if ! command -v linear >/dev/null 2>&1; then
     linear_cmd=(mise exec -- linear)
   fi

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

8. Verify CI for the merge commit:
   Run `gh run list --repo edwinhern/dotfiles --branch main --commit <MERGE_SHA> --workflow CI --json databaseId,displayTitle,workflowName,status,conclusion,headSha,url --limit 1`.
   Require one `CI` workflow run for `<MERGE_SHA>` and require it to have `status` `completed` and `conclusion` `success`.

9. Verify final local state:
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
````

- [ ] **Step 2: Check removed GitHub Project verification language**

Run:

```bash
rg 'GitHub Project|gh project|closingIssuesReferences|project\s+item' .agents/skills/post-merge-cleanup/SKILL.md
```

Expected: no matches. `rg` exits `1` when there are no matches, which is acceptable for this check.

- [ ] **Step 3: Check Linear verification language exists**

Run:

```bash
rg 'Linear|DOT-\*|state type `completed`|linear issue query' .agents/skills/post-merge-cleanup/SKILL.md
```

Expected: matches in the description, scope, workflow, and report sections.

- [ ] **Step 4: Run formatting and lint checks**

Run:

```bash
mise lint
```

Expected: Prettier reports all matched files use Prettier code style and taplo completes without errors.

- [ ] **Step 5: Commit the post-merge skill change if commits are approved for this execution**

Run only when the user has explicitly approved commits:

```bash
git add .agents/skills/post-merge-cleanup/SKILL.md
git commit -m "fix: verify Linear after merges"
```

Expected: one commit containing only the post-merge cleanup skill update.

### Task 5: Clean Up GitHub Tracking Surfaces

**Files:**

- Modify: GitHub issues `#16`, `#17`, `#18`, `#20`, `#21`, and `#22`
- Modify: GitHub Project `dotfiles` number `6`

- [ ] **Step 1: Verify Linear issue mapping before closing GitHub issues**

Run:

```bash
for id in DOT-5 DOT-6 DOT-7 DOT-9 DOT-10 DOT-11; do
  mise exec -- linear issue query --team DOT --search "$id" --include-archived --json --limit 10 |
    jq -r --arg id "$id" '([.nodes[] | select(.identifier == $id)][0]) | "\(.identifier): priority \(.priority), state \(.state.name), \(.url)"'
done
```

Expected: six lines with the target priority and state values from the design spec.

- [ ] **Step 2: Close migrated open GitHub issues with Linear migration comments**

Run:

```bash
gh issue close 16 --repo edwinhern/dotfiles --reason "not planned" --comment "Migrated to Linear as DOT-5. Future tracking continues in Linear."
gh issue close 17 --repo edwinhern/dotfiles --reason "not planned" --comment "Migrated to Linear as DOT-6. Future tracking continues in Linear."
gh issue close 18 --repo edwinhern/dotfiles --reason "not planned" --comment "Migrated to Linear as DOT-7. Future tracking continues in Linear."
gh issue close 20 --repo edwinhern/dotfiles --reason "not planned" --comment "Migrated to Linear as DOT-9. Future tracking continues in Linear."
gh issue close 21 --repo edwinhern/dotfiles --reason "not planned" --comment "Migrated to Linear as DOT-10. Future tracking continues in Linear."
gh issue close 22 --repo edwinhern/dotfiles --reason "not planned" --comment "Migrated to Linear as DOT-11. Future tracking continues in Linear."
```

Expected: each command reports the issue was closed.

- [ ] **Step 3: Verify no open GitHub issues remain**

Run:

```bash
gh issue list --repo edwinhern/dotfiles --state open --limit 100 --json number,title,url
```

Expected:

```json
[]
```

- [ ] **Step 4: Close the GitHub Project board**

Run:

```bash
gh project close 6 --owner edwinhern --format json -q '.closed'
```

Expected:

```text
true
```

- [ ] **Step 5: Verify the GitHub Project is closed**

Run:

```bash
gh project view 6 --owner edwinhern --format json -q '{title: .title, closed: .closed}'
```

Expected:

```json
{ "closed": true, "title": "dotfiles" }
```

### Task 6: Final Verification

**Files:**

- Verify: `AGENTS.md`
- Verify: `.agents/skills/post-merge-cleanup/SKILL.md`
- Verify: Linear team `dotfiles` (`DOT`)
- Verify: GitHub repo `edwinhern/dotfiles`

- [ ] **Step 1: Verify repository text no longer points agents to GitHub planning**

Run:

```bash
rg 'GitHub Issues are the source|GitHub Project named|dotfiles project `Priority`|Track active work by moving the issue in the `dotfiles` project|Closes #123|Fixes #123' AGENTS.md .agents/skills/post-merge-cleanup/SKILL.md
```

Expected: no matches. `rg` exits `1` when there are no matches, which is acceptable for this check.

- [ ] **Step 2: Verify Linear guidance exists in repo files**

Run:

```bash
rg 'Linear|DOT|Fixes DOT-123' AGENTS.md .agents/skills/post-merge-cleanup/SKILL.md
```

Expected: matches in both files.

- [ ] **Step 3: Verify the post-merge cleanup skill exists in the auto-scanned project path**

Run:

```bash
test -f .agents/skills/post-merge-cleanup/SKILL.md && printf 'post-merge cleanup skill present\n'
```

Expected: prints `post-merge cleanup skill present`.

- [ ] **Step 4: Verify Linear active and archived issue states**

Run:

```bash
for id in DOT-5 DOT-6 DOT-7 DOT-9 DOT-10 DOT-11; do
  mise exec -- linear issue query --team DOT --search "$id" --include-archived --json --limit 10 |
    jq -r --arg id "$id" '([.nodes[] | select(.identifier == $id)][0]) | "\(.identifier): priority \(.priority) state \(.state.name) type \(.state.type)"'
done

for id in DOT-8 DOT-12 DOT-13 DOT-14 DOT-15 DOT-16 DOT-17 DOT-18 DOT-19 DOT-20; do
  mise exec -- linear issue query --team DOT --search "$id" --include-archived --json --limit 10 |
    jq -r --arg id "$id" '([.nodes[] | select(.identifier == $id)][0]) | "\(.identifier): state \(.state.name) type \(.state.type) archived \(.archivedAt != null)"'
done
```

Expected: active issues show `DOT-7` priority `2` in `In Progress`, `DOT-6` and `DOT-11` priority `3` in `Backlog`, and `DOT-5`, `DOT-9`, `DOT-10` priority `4` in `Backlog`; archived issues show ten imported completed issues with `archived: true`.

- [ ] **Step 5: Verify GitHub tracking cleanup**

Run:

```bash
gh issue list --repo edwinhern/dotfiles --state open --limit 100 --json number,title,url
gh project view 6 --owner edwinhern --format json -q '{title: .title, closed: .closed}'
```

Expected: the issue list is `[]`, and the project output has `title` `dotfiles` and `closed` `true`.

- [ ] **Step 6: Run repository verification**

Run:

```bash
git diff --check
mise lint
git status --short
```

Expected: `git diff --check` has no output, `mise lint` passes, and `git status --short` shows only intended files.

- [ ] **Step 7: Commit the final verification docs if commits are approved for this execution**

Run only when the user has explicitly approved commits and the spec or plan files are still uncommitted:

```bash
git add docs/superpowers/specs/2026-05-21-linear-migration-design.md docs/superpowers/plans/2026-05-21-linear-migration.md
git commit -m "docs: plan Linear migration"
```

Expected: one docs commit, unless those files were already committed in an earlier approved step.

## Execution Notes

- If any Linear CLI command fails, stop and inspect that error before making another write.
- If the GitHub issue close step fails because an issue is already closed, verify the issue comment and state before continuing.
- If `gh project close` fails, keep the GitHub Project unchanged and report the exact error.
