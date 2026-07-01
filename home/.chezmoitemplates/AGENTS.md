# Agent Guidance

Behavioral guidelines for AI coding agents (Claude Code, GitHub Copilot, and others) to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations on LLM coding pitfalls](https://x.com/karpathy/status/2015883857489522876).

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them, don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it, don't delete it.

When your changes create orphans:

- Remove imports, variables, and functions that your changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" becomes "Write tests for invalid inputs, then make them pass".
- "Fix the bug" becomes "Write a test that reproduces it, then make it pass".
- "Refactor X" becomes "Ensure tests pass before and after".

For multi-step tasks, state a brief plan:

```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Writing Style

Never use words like "consolidate", "modernize", "streamline", "flexible", "delve", "establish", "enhanced", "comprehensive", or "optimize", nor em dashes or double hyphens, in docstrings, commit messages, or comments.

## GitHub CLI

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

## Graphify

- Use the installed Graphify skill when the user invokes `/graphify`.
- If `graphify-out/graph.json` exists, prefer `graphify query`, `graphify path`, or `graphify explain` before raw file search for codebase questions.
- Read `GRAPH_REPORT.md` only for broad architecture review or when graph commands do not answer the question.
- Treat `graphify-out/` as per-repo data and do not create it from a global setup script.
