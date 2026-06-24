# Personal AI Tools Design

## Goal

Set up personal-only AI tooling for the Claude Code migration without adding those tools to work hosts.

## Scope

- Install personal uv tools for `graphifyy` and `tavily-cli`.
- Install `tavily-ai/skills` through APM for personal hosts.
- Write personal APM skills to `~/.agents/skills` by adding the `agent-skills` target.
- Keep work APM target behavior limited to `copilot`.
- Update Claude Code settings so model choices follow current aliases instead of pinned old model IDs.
- Bring Claude Code bash permissions closer to the existing OpenCode bash allowlist while keeping existing deny and ask safeguards.

## Current Repo Shape

- `home/.chezmoidata/mise.yaml` already gates `uv` to personal hosts.
- `home/.chezmoidata/apm.yaml` already gates APM targets and dependencies by `shared`, `personal`, and `work` groups.
- `home/dot_apm/apm.yml.tmpl` renders APM targets, dependencies, and MCP servers from those groups.
- `home/.chezmoiscripts/darwin/run_onchange_03_install-mise-tools.sh.tmpl` installs mise tools before the APM install script runs.
- `home/dot_claude/settings.json` is the user-scoped Claude Code settings source.
- `home/dot_config/opencode/opencode.jsonc` is the user-scoped OpenCode settings source.

## Decisions

### APM Targets

Personal APM should target both `claude` and `agent-skills`.

Context7 docs for `/microsoft/apm` confirm that `claude` writes skills to `.claude/skills`, while `agent-skills` writes skill bundles to `.agents/skills`. `agent-skills` is not auto-detected, so it must be explicit in the personal target list.

This keeps Claude Code agents and instructions installed for Claude Code, while skill bundles like `tavily-ai/skills` are also available from the vendor-neutral skills path.

### OpenCode Impact

Do not add `opencode` as an APM target. Some APM agent packages carry Claude-specific model frontmatter that can break OpenCode when Anthropic model access changes. Skills are safer to share through `~/.agents/skills` because they do not need tool-specific model frontmatter.

### uv Tool Installs

Use a new personal-only chezmoi data group for uv tools and a new Darwin run script after mise installs `uv`.

The script should install each declared uv tool with `uv tool install --upgrade <package>`. This keeps the install repeatable and lets later chezmoi applies pick up package updates. The personal data should use the PyPI package names:

- `graphifyy`, which provides the `graphify` and `graphify-mcp` commands.
- `tavily-cli`, which provides the `tvly` command.

Work hosts should not render or run this installer.

### Claude Code Models

Use Claude Code model aliases instead of pinned `ANTHROPIC_DEFAULT_*_MODEL` values.

Preferred setting:

```json
"model": "opusplan[1m]"
```

This keeps planning on the latest Opus alias with a 1M context request and execution on the latest Sonnet alias. Removing the pinned default model environment variables avoids stale values as Opus and Sonnet aliases move forward. Keep other Claude Code environment tuning values unless they are clearly obsolete.

### Claude Code Permissions

Keep the existing Claude Code deny list for secrets and destructive commands. Add missing allow entries that mirror common OpenCode bash permissions for local development and dotfiles work, including read-only shell utilities, formatting tools, package managers, GitHub CLI read paths, Docker, Homebrew, and `linear`.

Do not copy OpenCode rules mechanically. Claude Code evaluates deny, then ask, then allow, so ask and deny rules should stay explicit for force pushes, hard resets, broad removals, sudo, and publish-like operations.

## Files To Change

- `home/.chezmoidata/apm.yaml`: add `agent-skills` to personal targets and `tavily-ai/skills` to personal dependencies.
- `home/.chezmoidata/uv.yaml`: add personal uv tool data with `graphifyy` and `tavily-cli`.
- `home/.chezmoiscripts/darwin/run_onchange_03_install-uv-tools.sh.tmpl`: new personal-only Darwin script that renders configured uv tools and injects a shell library. The filename shares the `03` prefix with the mise installer and sorts after it, so `uv` is installed before uv tools are installed.
- `home/.chezmoitemplates/lib/install/uv-tools.sh`: new sourceable shell library to install tools from a `UV_TOOLS` array.
- `tests/template/mise-config.bats`: assert `uv` remains personal-only and work excludes it.
- `tests/template/apm-config.bats`: assert personal renders `claude`, `agent-skills`, and `tavily-ai/skills`; assert work excludes personal targets and dependencies.
- `tests/template/darwin-install-scripts.bats`: assert the new uv tools script renders only for personal context and remains syntactically valid bash.
- `tests/unit/lib/install/uv-tools.bats`: test the uv tool installer behavior using a fake `uv` binary.
- `home/dot_claude/settings.json`: update model aliases and expand bash permission allows.

## Validation

- Run `mise exec -- bats tests/template/apm-config.bats tests/template/mise-config.bats tests/template/darwin-install-scripts.bats`.
- Run `mise exec -- bats tests/unit/lib/install/uv-tools.bats`.
- Run `mise test`.
- Run `mise lint`.
- Run `git diff --check`.

## Out Of Scope

- Adding personal tools to work hosts.
- Adding OpenCode as an APM target.
- Pinning exact Claude model IDs.
- Managing Tavily API keys or other secrets in chezmoi.
