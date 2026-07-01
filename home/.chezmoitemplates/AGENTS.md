# Agent Guidance

Guidance for AI coding agents (Claude Code, GitHub Copilot, and others). Structured around [Andrej Karpathy's observations on LLM coding pitfalls](https://x.com/karpathy/status/2015883857489522876): surface assumptions, don't overcomplicate, make surgical changes, verify before moving on.

## AI Guidance

**Do what was asked. Nothing more, nothing less.**

Never use words like "consolidate", "modernize", "streamline", "flexible", "delve", "establish", "enhanced", "comprehensive", "optimize" or em-dashes (—) and double-hyphens (--) in docstrings, commit messages, or comments.

- Reflect on tool results before acting. Use thinking to plan and iterate, then take the best next action.
- Run independent operations in parallel.
- Verify your solution before finishing.
- Never create files unless necessary. Prefer editing. Never create docs (\*.md, README) unless explicitly asked.
- Reuse existing code. Simplify. Make targeted changes, not sweeping ones.
- Prefer `rg` over `grep`.
- No defensive programming unless you state the motivation and the user approves.
- When updating code, check related code in the same and other files for consistency.

Ask yourself: "Does every change I'm making trace directly to what was asked?"

### GitHub CLI

Use `gh` CLI for all GitHub interactions. Never clone repositories to read code.

- **Read file from repo**: `gh api repos/{owner}/{repo}/contents/{path} -q .content | base64 -d`
- **Search code**: `gh search code "query" --repo {owner}/{repo}` or `gh search code "query" --language python`
- **Search repos**: `gh search repos "query" --language python --sort stars`
- **Compare commits**: `gh api repos/{owner}/{repo}/compare/{base}...{head}`
- **View PR**: `gh pr view {number} --repo {owner}/{repo}`
- **View PR diff**: `gh pr diff {number} --repo {owner}/{repo}`
- **View PR comments**: `gh api repos/{owner}/{repo}/pulls/{number}/comments`
- **List commits**: `gh api repos/{owner}/{repo}/commits --jq '.[].sha'`
- **View issue**: `gh issue view {number} --repo {owner}/{repo}`

## Git and Pull Request Workflows

### Commit Messages

- Format: `{type}: brief description` (max 50 chars first line)
- Optional second line: 1 sentence with findings/motivation
- Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`, `build`, `chore`, `ci`
- Simple terms, no jargon
- ONLY analyze staged files (`git diff --cached`), ignore unstaged
- NO test plans in commit messages

### Pull Requests

- PR titles: NO type prefix (unlike commits) - start with capital letter + verb
- Analyze ALL commits with `git diff <base-branch>...HEAD`, not just latest
- PR body: single section, no headers, 1-2 sentences + usage snippet
- No test plans, no changed files list, no line-number links in PR body
- Self-assign with `-a @me`
- Find reviewers: `gh pr list --repo <owner>/<repo> --author @me --limit 5`

### PR Comments and Reviews

- Create pending reviews only, never auto-submit
- Comment style: start lowercase, no em-dashes, simple terms, no end punctuation, max 1 sentence
- Bot comment responses: few words is enough
- Real person responses: polite, concise

Ask yourself: "Would someone unfamiliar with this repo understand this commit message?"

## Graphify

- Use the installed Graphify skill when the user invokes `/graphify`.
- If `graphify-out/graph.json` exists, prefer `graphify query`, `graphify path`, or `graphify explain` before raw file search for codebase questions.
- Read `GRAPH_REPORT.md` only for broad architecture review or when graph commands do not answer the question.
- Treat `graphify-out/` as per-repo data and do not create it from a global setup script.
