# Linear Migration Design

**Status:** Approved for implementation.

**Branch:** `main`

**Linear team:** `dotfiles` (`DOT`)

## Context

This repository currently uses GitHub Issues as the work item source of truth and a GitHub Project named `dotfiles` as the visual board. The current repo instructions also tell agents to select work from the GitHub Project `Priority` field, move GitHub Project items to `In Progress`, and link Superpowers specs or plans from the related GitHub issue.

The user wants to move the planning source of truth to Linear for hands-on Linear experience and better board tooling while keeping GitHub for code, pull requests, and CI.

The Linear GitHub importer has already imported `edwinhern/dotfiles` into the Linear team `dotfiles` with key `DOT`. Read-only verification confirmed:

- Linear CLI is available to local agent processes through mise.
- The visible Linear team is `dotfiles` with key `DOT`.
- Linear has 20 issues for this team: 10 active issues and 10 archived completed issues.
- The 10 archived completed issues correspond to the closed GitHub issues.
- The 6 imported open GitHub issues are active in `Backlog`.
- Linear also has 4 completed onboarding issues created by Linear.

## Goal

Move this repo's planning workflow from GitHub Issues and GitHub Projects to Linear while preserving imported history, keeping Superpowers specs and plans in the repo, and keeping GitHub as the code and CI platform.

## Non-Goals

- Do not use Linear MCP.
- Do not build a Linear OAuth app or app-actor agent in this migration.
- Do not keep GitHub Issues as an active second source of truth.
- Do not create a custom Linear priority field.
- Do not commit or expose the Linear API key.
- Do not replace GitHub pull requests, GitHub Actions, or release history.

## Recommended Approach

Use Linear's native GitHub importer for the historical migration, then run a focused cleanup pass with Linear-native issue properties.

The importer preserves more issue history than a custom API import, including issue descriptions, comments, labels, sub-issues where supported, and completed issue history. The cleanup pass should fix the pieces GitHub Project imports do not carry cleanly: priority, exact active status, and any desired label naming.

Repo agent instructions should point agents at Linear through the mise-managed `linear` CLI. Repo-local skills should document CLI workflows only.

## Linear Structure

### Team

Use one Linear team for this repository:

- Name: `dotfiles`
- Key: `DOT`

Future Linear issue IDs will use this key, such as `DOT-7`.

### Workflow States

Use Linear workflow states instead of GitHub Project status fields.

Current verified states include:

- `Backlog` (`backlog`)
- `Todo` (`unstarted`)
- `In Progress` (`started`)
- `In Review` (`started`)
- `Done` (`completed`)
- `Canceled` (`canceled`)
- `Duplicate` (`duplicate`)

Agent work should use:

- `Backlog` or `Todo` for not-started work.
- `In Progress` for active implementation.
- `In Review` when a PR exists but work is not merged.
- `Done` when the work is complete.

### Priority

Use Linear's native issue priority.

Mapping from the GitHub Project priority field:

- GitHub `High` maps to Linear `High`.
- GitHub `Normal` maps to Linear `Medium`.
- GitHub `Low` maps to Linear `Low`.

Linear also supports `Urgent`, but this repo should reserve it for security, broken reproducibility, or a blocked daily workflow that needs immediate attention.

### Labels

Keep area as labels because Linear does not have a native area field.

Current imported labels include:

- `area:apm`
- `area:agents`
- `area:chezmoi`
- `area:ci`
- `area:docs`
- `area:editor`
- `enhancement`
- `priority:high`
- `Migrated`

Recommended cleanup:

- Keep area labels as the repo domain filter.
- Remove or stop using `priority:high` once Linear native priority is set.
- Keep `Migrated` if it is useful for audit, otherwise remove it after verification.
- Optionally rename `area:*` to `area/...` later if Linear label grouping is configured.

### Projects And Hierarchy

Do not recreate GitHub Projects as Linear Projects.

Use Linear Projects only for outcome-based work that spans multiple issues. Use labels for areas, and use sub-issues for implementation breakdown under one issue.

Initial project candidates if they become useful:

- `APM secrets handling`
- `CI maintenance`
- `Agent workflow`
- `Editor workflow`
- `Chezmoi migration`

Skip Initiatives for now. Add them later only if multiple Linear Projects need higher-level grouping.

## Current Import State

The importer created active issues for the six open GitHub issues, but they currently have Linear priority `0` and state `Backlog`.

Cleanup should map them as follows:

| Linear issue | GitHub issue | Title                                           | Target priority | Target state |
| ------------ | ------------ | ----------------------------------------------- | --------------- | ------------ |
| `DOT-7`      | `#18`        | Design Bitwarden-backed APM secrets handling    | High            | In Progress  |
| `DOT-6`      | `#17`        | Decide APM audit governance needs               | Medium          | Backlog      |
| `DOT-11`     | `#22`        | Evaluate reducing the lint toolchain            | Medium          | Backlog      |
| `DOT-5`      | `#16`        | Decide whether a business APM package is needed | Low             | Backlog      |
| `DOT-9`      | `#20`        | Evaluate mise tool caching in CI                | Low             | Backlog      |
| `DOT-10`     | `#21`        | Evaluate docs-only CI gating                    | Low             | Backlog      |

The archived completed issues verified through Linear are:

- `DOT-8`: Remove curl-installed chezmoi from CI
- `DOT-12`: Set up issue and project planning workflow
- `DOT-13`: Add priority-based task selection workflow
- `DOT-14`: Create repo-local post-merge cleanup skill
- `DOT-15`: Set up LazyVim tmux opencode workflow
- `DOT-16`: Add opencode.nvim integration
- `DOT-17`: Integrate zsh CLI tool helpers
- `DOT-18`: Improve LazyVim and tmux workflow
- `DOT-19`: Prepare work laptop migration
- `DOT-20`: Make work APM MCP servers data-driven

## Authentication And Tooling

Use the `linear` CLI for local agent automation.

Rules:

- Install `npm:@schpet/linear-cli` through mise for personal hosts.
- Prefer `linear` when it is on `PATH`; otherwise run `mise exec -- linear`.
- Use `linear issue query --team DOT --include-archived --json` for issue verification.
- Use `jq` to inspect CLI JSON before trusting the result.

OAuth is a later project only if the repo needs a native Linear app actor, assignment handling, webhooks, or Codex-style agent progress updates.

## Agent Workflow

Agents working in this repo should treat Linear as the planning source of truth, regardless of which agent reads the repo guidance.

When starting work:

1. Query Linear team `dotfiles` (`DOT`) for active issues.
2. Prefer `High`, then `Medium`, then `Low` priority.
3. If priorities tie, choose security and reproducibility work first, then blockers, then the smallest clear issue.
4. If priority is missing, set it or ask one question before implementation starts.
5. Move the selected Linear issue to `In Progress` before code changes.
6. Link the related Superpowers spec or plan from the Linear issue description or a Linear comment before implementation starts.

During PR work:

1. Keep GitHub as the code review and CI platform.
2. Include the Linear issue ID in the branch, PR title, or PR body.
3. Use closing words such as `Fixes DOT-7` when merging should complete the Linear issue.
4. After merge, verify GitHub CI and Linear issue status.

## Repo Changes Needed

Implementation should update repo guidance and automation around Linear:

- Update `AGENTS.md` so Linear replaces GitHub Issues and GitHub Projects as the work tracking source of truth.
- Update the post-merge cleanup skill so it verifies Linear issue status instead of GitHub Project item status.
- Add Linear CLI to the personal mise config and cover it with a template test.
- Render APM dependencies from `home/.chezmoidata/apm.yaml` so shared packages stay shared and `schpet/linear-cli` stays personal-only.
- Remove or de-emphasize GitHub issue/project commands from the active planning workflow.

Install `npm:@schpet/linear-cli` through mise for personal hosts so CLI-backed workflows can use `linear` or `mise exec -- linear`. Install the APM `schpet/linear-cli` skill dependency only for personal hosts. Do not add a Homebrew tap or formula for Linear.

## Migration And Cutover

The import is already complete, so cutover should focus on validation and instruction changes.

1. Verify the importer preserved issue descriptions, comments, and labels for a sample of active and archived issues.
2. Set Linear native priority on the six imported open issues.
3. Move `DOT-7` to `In Progress` because it was active in the GitHub Project.
4. Keep the other five imported open issues in `Backlog` until they are selected for work.
5. Stop using GitHub Issues for new work.
6. Update repo agent instructions to point agents at Linear.
7. Use GitHub PR integration and Linear issue IDs for future code changes.
8. Keep long-term GitHub Issues sync disabled unless there is a later explicit reason to turn it on.
9. After Linear is verified as the source of truth, close the remaining open GitHub issues with a migration note that points to the matching Linear issue.
10. Archive or delete the GitHub Project named `dotfiles` so stale board data is no longer visible as a parallel backlog.

GitHub should remain responsible for code, pull requests, CI, releases, and old PR links. GitHub Issues and the GitHub Project should not remain visible as a parallel backlog after cutover.

## Error Handling

If an agent process cannot run `linear`, retry through `mise exec -- linear`. If that fails on a non-personal host, stop and rerun the Linear-dependent workflow from a personal host because Linear CLI is intentionally personal-only.

If importer data is broadly wrong, use Linear's importer rollback window before doing manual repair.

If only priority, area labels, or active status are wrong, repair them in Linear UI or through the Linear CLI without rolling back the import.

If GitHub PR linking does not update Linear as expected, verify the GitHub integration settings and use explicit issue IDs or closing words in the PR body.

## Verification

Verify the migration and implementation with:

- `linear --version` or `mise exec -- linear --version`.
- `linear issue query --team DOT --include-archived --json` checks for active and archived issues.
- A sample check of at least one active issue and one archived completed issue in the Linear UI.
- The exact UI filter, saved view, or CLI query used to inspect archived migrated issues if the default Linear view hides them.
- `git diff --check`
- `mise lint`

The work is complete when Linear is the documented source of truth, the six open migrated issues have correct native Linear priority and status, archived completed issues are searchable, repo agent guidance points to Linear, stale GitHub tracking surfaces are cleaned up, and GitHub remains responsible for PRs and CI.
