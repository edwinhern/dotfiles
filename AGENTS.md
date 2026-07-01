# AGENTS.md

## Repository Context

- This repository is managed with [`chezmoi`](https://www.chezmoi.io/) ([GitHub](https://github.com/twpayne/chezmoi)).
- Files under `home/` are the public source state and are applied by `chezmoi` into the user's `$HOME` directory.

## Response Rule

- After reading this `AGENTS.md`, say: `🤖 I read the CLAUDE.md for edwinhern/dotfiles.`

## Comment Policy

- When adding or updating comments for shell scripts or shell-based executables, always write them in English using shdoc-compatible format.

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

## Linear / GitHub PR Flow

- Start branch work from a Linear `DOT-*` issue.
- If no issue exists, create one in the Linear `dotfiles` team, set priority, and keep it in `Backlog` or `Todo` until work starts.
- When work starts, assign yourself and move the issue to `In Progress`.
- Prefer Linear's generated branch name from `linear issue start DOT-123` or Copy git branch name, such as `feature/dot-123-short-title`.
- Open the PR from that branch so Linear links it by branch name. The PR title or body may also include the same `DOT-*` ID.
- Use `Fixes DOT-123` in the PR body only when merge should move the issue to `Done`. Use `Refs DOT-123` when merge should not close it.
- After opening the PR, verify the Linear issue shows the GitHub PR attachment and the PR references the correct `DOT-*` issue.

## Git / PR Workflow

- After pushing to GitHub, always check the GitHub Actions CI results. If CI fails, investigate the failure, fix the issue, push again, and repeat until all CI checks pass.
