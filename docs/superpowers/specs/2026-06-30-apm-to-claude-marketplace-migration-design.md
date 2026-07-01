# APM to Cross-Agent AI Tooling Migration Design

**Status:** Approved for implementation.

**Issue:** [DOT-43](https://linear.app/edwinhern/issue/DOT-43/migrate-personal-ai-setup-from-apm-to-claude-plugin-marketplaces)

## Goal

Make the dotfiles repo the single source of truth for AI tooling across Claude Code and GitHub Copilot. Remove APM. Deliver skills through the cross-agent `skills` CLI (skills.sh), reserve Claude plugins for hook-bearing bundles, and apply MCP servers to every agent. Drive all of it from group and agent scoped data, the way APM targets worked.

## Background

APM did three jobs: fetch skill and plugin source, pin versions, and wire runtime into `~/.claude`. Its partial caveman hook install caused broken hook paths. APM was also chosen to keep instructions agnostic across agents. The `skills` CLI now installs one skill into multiple agents from a single command, native `AGENTS.md` covers cross-agent instructions, and chezmoi already renders per group. Personal use is Claude Code; work use is Copilot in VS Code.

## Delivery Model

The deciding question for each artifact is: does it need a hook, statusline, or slash command on Claude?

| Artifact   | Definition                                                                               | Delivery             | Cross-agent                               |
| ---------- | ---------------------------------------------------------------------------------------- | -------------------- | ----------------------------------------- |
| Skill      | Instructions or knowledge, no runtime                                                    | `npx skills add`     | One command, both agents                  |
| Plugin     | Bundle with hooks, statusline, slash commands, or packaged agents that only Claude loads | `claude plugin`      | Claude only; Copilot uses skills or rules |
| MCP server | A tool or data backend spoken over MCP                                                   | Per-agent MCP config | Write each agent's config                 |

Plugins are reserved for hook-bearing bundles. Everything that is only a skill goes through the `skills` CLI to the targeted agents. MCP servers are written into each targeted agent's config.

## Group and Agent Data Model

A new `home/.chezmoidata/ai.yaml` declares what to install, scoped by group and agent, replacing `home/.chezmoidata/apm.yaml`. Active groups per machine come from the existing `lib/chezmoi/active-groups.json.tmpl`, the same mechanism APM used.

Agent identifiers follow the `skills` CLI: `claude-code` and `github-copilot`.

```yaml
ai:
  skills:
    # Almost everything is shared; the agents list does the real scoping.
    shared:
      - source: mattpocock/skills
        skill: grill-me
        agents: [claude-code, github-copilot]
      - source: schpet/linear-cli
        skill: linear-cli
        agents: [claude-code]
      - source: juliusbrussee/skills
        skill: junior-to-senior
        agents: [claude-code, github-copilot]
      - source: juliusbrussee/skills
        skill: interface-kit
        agents: [claude-code, github-copilot]
      - source: blader/humanizer
        skill: humanizer
        agents: [claude-code, github-copilot]
      - source: imadAttar/kaizen
        skill: kaizen
        agents: [claude-code, github-copilot]
      - source: upstash/context7
        skill: context7-cli
        agents: [claude-code, github-copilot]
      - source: anthropics/claude-plugins-official
        skill: skill-creator
        agents: [claude-code]
      # local domain skills authored in this repo
      - source: local
        skill: typescript
        agents: [claude-code, github-copilot]
      - source: local
        skill: react
        agents: [claude-code, github-copilot]
      - source: local
        skill: testing
        agents: [claude-code, github-copilot]
  plugins:
    # Dual-path: claude-code via marketplace, github-copilot via skills CLI.
    shared:
      - name: caveman
        marketplace: caveman
        source: JuliusBrussee/caveman
        agents: [claude-code, github-copilot]
      - name: superpowers
        marketplace: superpowers-dev
        source: obra/superpowers
        agents: [claude-code, github-copilot]
  mcp:
    shared:
      - name: grep
        transport: http
        url: https://mcp.grep.app
        agents: [claude-code, github-copilot]
    personal:
      - name: tavily
        transport: http
        url: https://mcp.tavily.com/mcp/
        agents: [claude-code]
    work:
      - name: figma
        transport: http
        url: https://mcp.figma.com/mcp
        agents: [github-copilot]
      - name: jira
        transport: http
        url: https://mcp.atlassian.com/v1/mcp
        agents: [github-copilot]
```

Skills are all `shared`; the `agents` list scopes each to Claude, Copilot, or both. `linear-cli` and `skill-creator` are Claude only. The `personal` and `work` groups are used only for MCP and work-specific items. Personal machines install shared plus personal entries; work machines install shared plus work entries. `tavily` MCP is Claude only. `deep-analysis` is deferred to the work Copilot setup and is not listed until that work starts.

## Skills Design

Skills install with the cross-agent CLI. For each entry the install script runs:

```bash
npx skills add <source> --skill <skill> -a <agent> [-a <agent>] --global --copy --yes
```

`--global` installs into `~/.claude/skills/` and `~/.copilot/skills/`. `--copy` writes real files rather than symlinks because Claude Code ignores symlinked skill directories. Agent flags come from the entry's `agents` list.

Local domain skills (`typescript`, `react`, `testing`, React Testing Library) are authored under `home/.chezmoitemplates/skills/` from the existing instruction files, and installed with `source: local` pointing at that path. The vendored `grill-me` and `junior-to-senior` copies already present under that directory are removed once they install from upstream sources, unless upstream is unavailable.

`skill-creator` comes from the `anthropics/claude-plugins-official` marketplace repo rather than a plain skills repo, so implementation verifies that `skills add` can pull it. If it cannot, `skill-creator` installs as a Claude plugin instead. It stays Claude only either way.

The `skills` CLI has no manifest file, so `home/.chezmoidata/ai.yaml` is the manifest. A `run_onchange_09_install-ai-skills.sh.tmpl` script iterates the active groups' skill entries and runs the CLI. It re-runs when the rendered data changes.

## Plugins Design

Plugins are hook-bearing bundles: `caveman` and `superpowers`. Each plugin installs by a different path per agent, driven by its `agents` list.

- `claude-code`: through the marketplace.

  ```bash
  claude plugin marketplace add <source>
  claude plugin install <name>@<marketplace>
  ```

- `github-copilot`: through the cross-agent skills CLI, since Copilot has no plugin or hook system.

  ```bash
  npx skills add <source> -a github-copilot --global --copy --yes
  ```

`run_onchange_06_install-claude-plugins.sh.tmpl` iterates the active groups' plugin entries and runs the path that matches each targeted agent present on the machine. This replaces `run_onchange_06_install-apm.sh.tmpl`. Marketplaces and enabled plugins are also declared in `home/dot_claude/settings.json`.

Caveman installs as a plugin on Claude, so Claude Code loads its hooks from the plugin directory. The manual caveman and superpowers hook entries stay removed from `settings.json`. On the Copilot side the plugins install as skills only, because Copilot has no hooks; the Copilot path runs only on a machine where Copilot is present.

## MCP Design

Shared MCP servers apply to every targeted agent, so `grep` reaches both Claude and Copilot. Per agent:

- Claude Code: registered at user scope, for example `claude mcp add --scope user --transport http grep https://mcp.grep.app`, or the equivalent user config entry.
- Copilot VS Code: written into `home/Library/Application Support/Code/User/mcp.json`.
- Copilot CLI: written into `home/dot_copilot/mcp-config.json`.

A `run_onchange` MCP script iterates the active groups' MCP entries and applies each to its targeted agents. `tavily` is Claude only. Work MCP servers use the HTTP transport with the vendor's MCP URL, including Jira at `https://mcp.atlassian.com/v1/mcp`, and authenticate over OAuth at connect time rather than a stored token. Any remaining secret values use `${VAR}` placeholders kept out of source control, sourced from `~/.secrets.local` on the work machine.

## Instructions Design

One canonical `home/.chezmoitemplates/AGENTS.md` holds universal behavioral guidance only: AI guidance, git and pull request workflow, commit message rules, and the `gh` CLI standard. It does not assert a frontend persona. Frontend specifics live in the `typescript`, `react`, and `testing` skills.

`AGENTS.md` renders to `~/.claude/CLAUDE.md` for Claude Code and to the Copilot instructions path for VS Code Copilot. GitHub MCP references and the `context7` tool mention are removed from the meta rules content; GitHub operations use `gh`. The `coding-standards` and TypeScript specifics fold into the `typescript` skill.

## Commit Message Instructions

VS Code Source Control commit generation reads `github.copilot.chat.commitMessageGeneration.instructions` in `home/Library/Application Support/Code/User/settings.json`. That file stays plain managed JSON, not a chezmoi template, to keep JSON schema IntelliSense and hover help.

The two generic entries are replaced with the `commit-guide` rules as inline `{ "text": ... }` entries: conventional commit format, imperative mood, subject under 50 characters, optional one-line body, no test plans. The workspace-relative `{ "file": ... }` form is not used because it has no global equivalent. The small duplication with the `AGENTS.md` git section is accepted to preserve IntelliSense. This shapes only the generated message, which is reviewed in Source Control. It does not automate committing or pushing.

## Work and Copilot Design

Work Copilot tooling is organized now and wired later.

```
home/Library/Application Support/Code/User/mcp.json   # work MCP, from ai.yaml
home/dot_copilot/skills/                              # Copilot skills, from skills CLI
home/dot_copilot/agents/                              # code-reviewer, ts-reviewer, research
home/dot_copilot/mcp-config.json                      # Copilot CLI MCP, from ai.yaml
```

The custom agents move to the Copilot side because they are frontend and work focused. Personal Claude keeps no custom agents and relies on plugin-provided agents such as the caveman reviewer. `deep-analysis` joins the work Copilot skills when that setup starts.

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

The manual caveman and superpowers hook entries stay removed from `settings.json`, because the caveman plugin supplies its hooks.

## Testing and Verification

- `chezmoi apply` on a clean state succeeds.
- Template tests verify personal rendering includes shared plus personal entries and excludes work entries, and work rendering includes shared plus work entries.
- After apply, `~/.claude/skills` and `~/.copilot/skills` contain the group-targeted skills; Claude-only skills like `linear-cli` are absent from `~/.copilot/skills`.
- `claude plugin list` shows caveman and superpowers.
- `grep` MCP is registered for both Claude and Copilot; `tavily` MCP is registered for Claude only.
- The VS Code commit button produces a message in the configured style.
- A new session `/doctor` reports no hook or settings errors.
- `command -v apm` returns nothing and `~/.apm` is absent.
- The bats suite passes, including tests for the new install scripts.

## Implementation Phases

1. Add `home/.chezmoidata/ai.yaml` and the skills install script, so Claude and Copilot get skills.
2. Add the plugins install script for caveman and superpowers.
3. Add the MCP install script and apply shared MCP to both agents.
4. Author `AGENTS.md` universal instructions and wire the Copilot commit instructions.
5. Author the local domain skills from the instruction files.
6. Organize the work and Copilot files.
7. Remove APM and update tests.

## Out of Scope

- Wiring work Copilot MCP authentication or enabling the work skill at runtime.
- Installing caveman and superpowers into Copilot beyond the deferred setup.
- Migrating work to Claude.
- Adding a secret backend.
- Verifying live Figma or Jira MCP authentication.
