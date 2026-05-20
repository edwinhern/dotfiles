# Work APM MCP Data Design

**Status:** Approved for implementation.

**Issue:** [#41](https://github.com/edwinhern/dotfiles/issues/41)

## Goal

Render work-only APM MCP servers from source data so the work laptop can use Figma plus separate Atlassian Jira and Knowledge MCP resources without committing tokens or resource URL values.

## Scope

- Keep `home/dot_apm/apm.yml.tmpl` as a chezmoi template.
- Move MCP server definitions into a data file under `home/.chezmoidata/`.
- Keep the always-on `grep` MCP server shared.
- Render Figma, Atlassian Jira, and Atlassian Knowledge only when `.work` is true.
- Use environment placeholders for secret and work-specific values.
- Do not render actual token or Atlassian resource URL values into source-controlled files.

## Template Design

`home/dot_apm/apm.yml.tmpl` stays a template because the APM project still needs chezmoi context:

- Personal machines should render only shared MCP servers.
- Work machines should render shared and work MCP servers.
- The template should build an MCP group list starting with `shared`, then append `personal` or `work` when that context is active.
- The MCP server list should be generated from data rather than hand-maintained inside the template.
- The reusable MCP server YAML snippet should live in `home/.chezmoitemplates/apm/mcp-server.yml.tmpl`, stay flush-left, and be injected with `{{ includeTemplate "apm/mcp-server.yml.tmpl" . | trim | indent 4 }}`.

The rendered target remains `~/.apm/apm.yml` because chezmoi strips the `.tmpl` suffix when applying source state.

## Data Design

Add `home/.chezmoidata/apm.yaml` with this shape:

```yaml
apm:
  mcp:
    shared:
      - name: grep
        registry: false
        transport: http
        url: https://mcp.grep.app

    personal: []

    work:
      - name: figma
        registry: false
        transport: http
        url: https://mcp.figma.com/mcp
        headers:
          Authorization: "Bearer ${FIGMA_TOKEN}"

      - name: atlassian-jira
        registry: false
        transport: stdio
        command: npx
        args:
          - "-y"
          - "mcp-remote"
          - "https://mcp.atlassian.com/v1/mcp"
          - "--resource"
          - "${ATLASSIAN_JIRA_RESOURCE_URL}"

      - name: atlassian-knowledge
        registry: false
        transport: stdio
        command: npx
        args:
          - "-y"
          - "mcp-remote"
          - "https://mcp.atlassian.com/v1/mcp"
          - "--resource"
          - "${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}"
```

APM supports `${VAR}` and `${env:VAR}` placeholders in MCP `headers` and `env` values. APM also documents `${VAR}` as the recommended cross-target form for new manifests. This design uses `${VAR}` placeholders for Figma and Atlassian values so the source repo never stores the secret values.

## Work Laptop Setup

On the work laptop, maintain `~/.secrets.local` by hand with the needed exports:

```sh
export FIGMA_TOKEN="..."
export ATLASSIAN_JIRA_RESOURCE_URL="https://your-company.atlassian.net/..."
export ATLASSIAN_KNOWLEDGE_RESOURCE_URL="https://your-company.atlassian.net/..."
```

The zsh config already sources `~/.secrets.local` when it exists. For tools started outside an interactive zsh session, open a fresh terminal after editing `~/.secrets.local` or source it before running APM/OpenCode-related commands.

## Testing

- Add template tests for `home/dot_apm/apm.yml.tmpl`.
- Verify personal rendering includes `grep` but excludes Figma and Atlassian work MCP servers.
- Verify work rendering includes `grep`, `figma`, `atlassian-jira`, and `atlassian-knowledge`.
- Verify work rendering includes `${FIGMA_TOKEN}`, `${ATLASSIAN_JIRA_RESOURCE_URL}`, and `${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}` literally.
- Verify rendering no longer requires `.atlassian_resource_url`.
- Run `mise check`.

## Out of Scope

- Managing the actual work token values with chezmoi.
- Adding Bitwarden or another secret backend in this change.
- Verifying live Figma or Atlassian MCP authentication.
- Changing non-APM OpenCode MCP configuration.
