# AI Tooling Separation Design

## Goal

Keep Claude Code, OpenCode, APM, and CLI tooling clear enough that new tools install in the right place and agent skills trigger only when they add value.

Linear issue: DOT-28

## Current State

- Source Claude Code settings use `opusplan[1m]`, alias-based model behavior, and `CLAUDE_CODE_SUBAGENT_MODEL=inherit`.
- Live Claude Code settings still have old exact Anthropic model pins, so the latest chezmoi source has not been applied.
- Source OpenCode config does not include live `small_model`, OpenAI model options, or `opencode-supermemory`.
- Live OpenCode has `opencode-supermemory`, but the user wants to remove it while moving back to Claude Code.
- APM now targets personal `claude` and `agent-skills`, and work `copilot`.
- Personal uv tools include `graphifyy` and `tavily-cli`.

## Tool Ownership Rules

APM manages portable agent assets:

- Shared skills that should land in `~/.agents/skills` through the `agent-skills` target.
- Claude-specific APM bundles that should land in `~/.claude` through the `claude` target.
- Work-only Copilot assets through the `copilot` target.
- MCP declarations that are safe across the chosen target.

APM should not manage tools that mutate host app runtime state through custom installers.

CLI tools live in package data:

- `uv.yaml` for uv tools such as `graphifyy` and `tavily-cli`.
- `mise.yaml`, package data, or app-specific files for non-uv tools.

Claude Code runtime integrations live outside APM unless they publish normal APM skills:

- Cozempic should be handled as a Claude Code plugin or Claude-only install script.
- Claude-Mem should be handled by its own installer or plugin flow, not as an APM dependency.
- Graphify platform installs should be audited before source-managing generated hooks, plugins, or instructions.

OpenCode runtime integrations live in OpenCode source files:

- Plugins belong in `home/dot_config/opencode/opencode.jsonc` and package files if needed.
- OpenCode-specific generated files should not be mixed with Claude Code hooks.
- `opencode-supermemory` should be removed from live state and kept out of source.

## Skill Triggering Policy

Skills should be installed only when their `description` has a clear trigger and the skill does not conflict with the repo workflow.

For JuliusBrussee skills:

- Add `junior-to-senior` if it can be installed without also installing the whole repo. It is useful when reviewing plans, architecture, and design decisions.
- Add `grill-me` if it can be installed without also installing the whole repo. It is useful when stress-testing a decision before implementation.
- Consider `interface-kit` only if frontend/UI work is common enough to justify another UI skill. It should not be installed just because it exists.
- Do not add `loop-factory` by default because Linear and Superpowers already own task flow.
- Do not add `context-canary` by default because it changes every response format.
- Do not add `fuck-slop` by default because the skill name and trigger style may not be desired globally.
- Do not add `caveman` again because it is already present.

## Cozempic Versus Claude-Mem

Use Cozempic first if the immediate problem is Claude Code context bloat and compaction hygiene.

Defer Claude-Mem because it is a larger memory platform with hooks, worker service, database, search UI, and cross-agent behavior. It may be useful later, but it should not be added while removing OpenCode Supermemory and cleaning the base Claude Code setup.

## Conservative First Pass

1. Reconcile source and live config without reintroducing OpenCode Supermemory.
2. Add only selected Julius skills if APM supports selecting individual skills from `JuliusBrussee/skills`.
3. Audit Graphify generated files before source-managing any `graphify install` output.
4. Defer Cozempic and Claude-Mem installation until Claude Code settings and installed skills are clean.
5. Run `mise update` only after source and live state are understood enough to avoid losing current preferences.

## Validation

- Run targeted template/unit tests for changed dotfiles.
- Run `mise test`.
- Run `mise lint`.
- Run `git diff --check`.
- Compare source and live Claude/OpenCode skill, agent, plugin, and settings state after `mise update`.
