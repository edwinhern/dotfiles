# Graphify Global Agent Install Design

## Goal

Install Graphify's global agent skills on personal machines so Claude Code and cross-framework agents can use `/graphify` in any repo, while keeping work machines free of personal Graphify setup.

## Current State

- `home/.chezmoi.yaml.tmpl` sets boolean context flags: `.personal` or `.work`.
- `home/.chezmoidata/apm.yaml` already uses the same grouped data shape for `shared`, `personal`, and `work`.
- Personal APM targets are `claude` and `agent-skills`.
- Work APM target is `copilot`.
- `home/.chezmoidata/uv.yaml` installs `graphifyy` only for personal machines.
- Several templates repeat the same group-selection logic: start with `shared`, append `personal` if `.personal`, append `work` if `.work`.
- Graphify's README separates CLI installation from assistant skill registration. `graphify install --platform agents` installs into the global Agent Skills location, and `graphify install --platform claude` installs the user-scope Claude skill.

## Chezmoi Helper Templates

Add small reusable templates under `home/.chezmoitemplates/lib/chezmoi/`:

- `active-groups.json.tmpl` renders a JSON array of active groups, always including `shared` and then including `personal` or `work` based on the current chezmoi data.
- `active-group-values.json.tmpl` accepts a grouped map such as `.apm.targets`, walks the active groups, and renders one JSON array with the values from those groups.

Callers parse helper output with `fromJson`, which is supported by chezmoi. This keeps the helper output typed after parsing and avoids shell parsing for template-time decisions.

Example use:

```gotemplate
{{- $targets := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .apm.targets) | fromJson -}}
```

## Graphify Skill Install Script

Add a Darwin run-on-change script after the uv tool install script:

- Render only when `.personal` is true and the mapped platform list is not empty.
- Derive targets from `.apm.targets` through the helper templates.
- Map `agent-skills` to Graphify platform `agents`.
- Map `claude` to Graphify platform `claude`.
- Ignore `copilot` and all unknown APM targets.
- Run `graphify install --platform "${platform}"` for each mapped platform.
- Check that `graphify` is present on `PATH`; if not, fail with a clear message pointing at the uv tool install script.

The script must not run any per-repo setup commands:

- Do not run `graphify .`.
- Do not run `graphify hook install`.
- Do not run `graphify claude install` or `graphify opencode install`, because those mutate the current repo.
- Do not configure MCP, because Graphify MCP needs a specific graph path.

## Managed Instructions

Chezmoi remains the owner of global Claude and OpenCode instruction files. Add a short Graphify section to `home/.chezmoitemplates/AGENTS.md` so both rendered files keep stable guidance even if Graphify's installer rewrites or appends its own user-scope block.

The shared instruction should say:

- Use the installed Graphify skill when the user invokes `/graphify`.
- If `graphify-out/graph.json` exists, prefer `graphify query`, `graphify path`, or `graphify explain` before raw file search for codebase questions.
- Read `GRAPH_REPORT.md` only for broad architecture review or when graph commands do not answer the question.
- Treat `graphify-out/` as per-repo data and do not create it from a global setup script.

## Source Files

Expected implementation files:

- `home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl`
- `home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl`
- `home/.chezmoitemplates/lib/install/graphify-skills.sh`
- `home/.chezmoiscripts/darwin/run_onchange_08_install-graphify-skills.sh.tmpl`
- `home/.chezmoitemplates/AGENTS.md`
- `tests/template/darwin-install-scripts.bats`
- `tests/template/agent-instructions.bats`
- `tests/unit/lib/install/graphify-skills.bats`

Existing APM and uv data files should remain the source of truth. The Graphify script should not add a separate Graphify target list unless the APM target model proves insufficient.

## Testing

Template tests should verify:

- Personal data renders Graphify platforms `agents` and `claude`.
- Work data renders no Graphify skill install commands.
- Empty groups produce no commands.
- Rendered Darwin scripts remain valid bash.
- Claude and OpenCode instruction templates both render the Graphify guidance.

Unit tests should verify:

- Missing `graphify` returns a non-zero status and logs the dependency hint.
- `GRAPHIFY_PLATFORMS=("agents" "claude")` runs the expected `graphify install --platform ...` commands.
- Empty `GRAPHIFY_PLATFORMS` exits cleanly.

## Follow-Up Policy

After this change, per-repo Graphify setup remains explicit. Agents can run `/graphify .` or `graphify .` inside a target repo when requested, and `graphify hook install` should only be suggested after that repo has a graph.
