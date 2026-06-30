# APM to Claude Marketplace Migration Design

**Status:** Approved for implementation.

**Issue:** [DOT-43](https://linear.app/edwinhern/issue/DOT-43/migrate-personal-ai-setup-from-apm-to-claude-plugin-marketplaces)

## Goal

Make the dotfiles repo the single source of truth for personal AI tooling. Remove APM entirely. Deliver Claude skills and plugins through official-first plugin marketplaces, share skills and instructions across Claude Code and GitHub Copilot from one source, and organize work-only Copilot tooling without wiring it yet.

## Background

APM currently does three jobs: it fetches skill and plugin source from git, pins versions, and wires runtime into `~/.claude`. Its partial caveman hook install caused broken hook paths. APM was also chosen to keep instructions agnostic across agents, which native `AGENTS.md` plus skills now cover. Personal use is Claude; work use is Copilot in VS Code.

## Scope

- Remove APM: source files, install script, lockfiles, runtime, and stale hook staging.
- Install Claude plugins from four marketplaces, official-first.
- Keep one canonical skills source and copy it into both `~/.claude/skills` and `~/.copilot/skills`.
- Keep one canonical `AGENTS.md` as universal behavioral instructions for both agents.
- Convert frontend-scoped guidance into skills (typescript, react, testing).
- Organize work Copilot MCP and the work skill, leaving Copilot wiring for later.
- Standardize on the `gh` CLI and remove GitHub MCP references.

## Plugin Marketplace Design

Personal Claude skills and plugins come from four marketplaces, preferring the Anthropic-vetted official marketplace where it carries the plugin.

| Plugin | Marketplace | Source |
| --- | --- | --- |
| superpowers, tavily, context7, skill-creator, linear | `claude-plugins-official` | anthropics/claude-plugins-official |
| caveman | `caveman` | JuliusBrussee/caveman |
| humanizer | `humanizer` | blader/humanizer |
| kaizen | `kaizen` | imadAttar/kaizen |

`linear` replaces the prior `schpet/linear-cli`. The official `linear` plugin uses Linear's MCP rather than the schpet CLI, an accepted behavior change.

Declare marketplaces in `home/dot_claude/settings.json` under `extraKnownMarketplaces` and enabled plugins under `enabledPlugins`. A `run_onchange_06_install-claude-plugins.sh.tmpl` script runs `claude plugin marketplace add` then `claude plugin install <plugin>@<marketplace>` idempotently, driven by a data list so the set stays declarative. This script replaces `run_onchange_06_install-apm.sh.tmpl`.

Caveman installs as a real plugin, so Claude Code loads its hooks from the plugin directory. The manual caveman and superpowers hook entries are already removed from `settings.json`.

## Skills Design

Canonical skills live under `home/.chezmoitemplates/skills/`:

- Vendored, no upstream marketplace: `grill-me`, `junior-to-senior` (already copied in).
- Frontend-scoped domain skills authored from the existing instruction files: `typescript`, `react`, `testing` (React Testing Library).

`run_onchange_09_install-ai-skills.sh.tmpl` copies each skill directory into both `~/.claude/skills/<name>` and `~/.copilot/skills/<name>`. The script copies rather than symlinks because Claude Code ignores symlinked skill directories. The script re-runs when skill content changes because its rendered hash changes.

Skill frontmatter compatibility between Claude `SKILL.md` and the Copilot skill format is verified during implementation. If the two formats diverge, the fan-out renders the agent-specific frontmatter while sharing the skill body.

## Instructions Design

One canonical `home/.chezmoitemplates/AGENTS.md` holds universal behavioral guidance only: AI guidance, git and pull request workflow, commit message rules, and the `gh` CLI standard. It does not assert a frontend persona, so the agent does not assume a single role. Frontend specifics live in the domain skills instead.

`AGENTS.md` renders to:

- `~/.claude/CLAUDE.md` for Claude Code.
- The Copilot `AGENTS.md` or user instructions path for VS Code Copilot.

GitHub MCP references and the `context7` tool mention are removed from the meta rules content. GitHub operations use `gh`. The `coding-standards` and TypeScript specifics fold into the `typescript` skill.

## Commit Message Instructions

The VS Code Source Control commit generation reads `github.copilot.chat.commitMessageGeneration.instructions` in `home/Library/Application Support/Code/User/settings.json`. That file stays a plain managed JSON file, not a chezmoi template, to keep JSON schema IntelliSense and hover help in the source.

The two generic commit entries are replaced with the `commit-guide` rules as inline `{ "text": ... }` entries: conventional commit format, imperative mood, subject under 50 characters, optional one-line body, no test plans. The workspace-relative `{ "file": ... }` form is not used because it has no global equivalent. The small duplication with the `AGENTS.md` git section is accepted to preserve IntelliSense.

This shapes only the generated message, which is reviewed in Source Control. It does not automate committing or pushing.

## Work and Copilot Design

Work Copilot tooling is organized now and wired later.

```
home/Library/Application Support/Code/User/mcp.json   # work MCP: figma, jira
home/dot_copilot/skills/deep-analysis/                # work skill, uses jira MCP
home/dot_copilot/agents/                              # code-reviewer, ts-reviewer, research
home/dot_copilot/mcp-config.json                      # Copilot CLI MCP, existing
```

`deep-analysis` leaves the personal Claude set. The custom agents move to the Copilot side because they are frontend and work focused. Personal Claude keeps no custom agents and relies on plugin-provided agents such as the caveman reviewer. Copilot wiring beyond file placement is out of scope.

## APM Teardown

Remove:

- `home/.chezmoidata/apm.yaml`
- `home/dot_apm/`
- `home/.chezmoitemplates/apm/`
- `home/.chezmoitemplates/lib/install/apm.sh`
- `home/.chezmoiscripts/darwin/run_onchange_06_install-apm.sh.tmpl`
- The APM entry in `mise.toml`
- Runtime `~/.apm`
- Stale `~/.claude/apm-hooks.json`

The already-removed caveman hook and reassert scripts on the current branch fold into this teardown. Update or remove the APM bats tests.

## Components Kept As Is

- The graphify install script `run_onchange_08_install-graphify-skills.sh.tmpl`.

The manual caveman and superpowers hook entries are already removed from `settings.json` and are not reintroduced, because the caveman plugin supplies its hooks.

## Testing and Verification

- `chezmoi apply` on a clean state succeeds.
- `claude plugin list` shows the enabled plugins from the four marketplaces.
- Skills resolve in both `~/.claude/skills` and `~/.copilot/skills`.
- The VS Code commit button produces a message in the configured style.
- A new session `/doctor` reports no hook or settings errors.
- `command -v apm` returns nothing and `~/.apm` is absent.
- The bats suite passes, including updated template tests for the new install scripts.

## Implementation Phases

1. Stand up the four marketplaces and the skills source plus fan-out script, so Claude never loses skills.
2. Author `AGENTS.md` universal instructions and wire the Copilot commit instructions.
3. Organize the work and Copilot files.
4. Remove APM and update tests.

## Out of Scope

- Wiring work Copilot MCP authentication or enabling the work skill at runtime.
- Migrating work to Claude.
- Adding a secret backend.
- Verifying live Figma or Jira MCP authentication.
