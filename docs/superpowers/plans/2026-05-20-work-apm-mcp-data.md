# Work APM MCP Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render shared and work APM MCP servers from chezmoi data while keeping work tokens and Atlassian resource URLs as shell environment placeholders.

**Architecture:** `home/.chezmoidata/apm.yaml` owns the MCP server list. `home/dot_apm/apm.yml.tmpl` remains a template and builds a `shared`/`personal`/`work` group list like the package installer before rendering MCP servers.

**Tech Stack:** chezmoi templates, YAML source data, APM manifest syntax, Bats template tests, mise checks.

---

## File Structure

- Create `home/.chezmoidata/apm.yaml`: shared and work MCP server declarations.
- Create `home/.chezmoitemplates/apm/mcp-server.yml.tmpl`: reusable MCP server YAML snippet.
- Modify `home/dot_apm/apm.yml.tmpl`: render MCP servers from the active `.apm.mcp` groups.
- Create `tests/template/apm-config.bats`: template rendering tests for personal and work APM manifests.

### Task 1: APM MCP Render Tests

**Files:**

- Create: `tests/template/apm-config.bats`
- Test: `tests/template/apm-config.bats`

- [ ] **Step 1: Add failing tests**

Create `tests/template/apm-config.bats` with three tests:

- personal rendering includes `name: grep` and excludes `figma`, `atlassian-jira`, `atlassian-knowledge`, `${FIGMA_TOKEN}`, `${ATLASSIAN_JIRA_RESOURCE_URL}`, and `${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}`.
- work rendering includes `name: grep`, `name: figma`, `Authorization: "Bearer ${FIGMA_TOKEN}"`, `name: atlassian-jira`, `name: atlassian-knowledge`, `"${ATLASSIAN_JIRA_RESOURCE_URL}"`, and `"${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}"`.
- work rendering succeeds without legacy `.atlassian_resource_url` data and excludes `atlassian_resource_url` from output.

- [ ] **Step 2: Verify tests fail before implementation**

Run: `mise exec -- bats tests/template/apm-config.bats`

Expected: FAIL because the current work render still depends on `.atlassian_resource_url` and has a single legacy `atlassian` MCP entry.

### Task 2: Data-Driven MCP Rendering

**Files:**

- Create: `home/.chezmoidata/apm.yaml`
- Create: `home/.chezmoitemplates/apm/mcp-server.yml.tmpl`
- Modify: `home/dot_apm/apm.yml.tmpl`
- Test: `tests/template/apm-config.bats`

- [ ] **Step 1: Add APM MCP data**

Create `home/.chezmoidata/apm.yaml` with shared `grep` and work `figma`, `atlassian-jira`, and `atlassian-knowledge` MCP servers. Use literal placeholders `${FIGMA_TOKEN}`, `${ATLASSIAN_JIRA_RESOURCE_URL}`, and `${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}`.

- [ ] **Step 2: Render MCP servers from data**

Create `home/.chezmoitemplates/apm/mcp-server.yml.tmpl` with the reusable MCP server YAML snippet flush-left. Update `home/dot_apm/apm.yml.tmpl` so it keeps the APM manifest header and dependencies, builds a group list starting with `shared`, appends `personal` or `work` when active, indexes each group from `.apm.mcp`, and injects the snippet with `{{ includeTemplate "apm/mcp-server.yml.tmpl" . | trim | indent 4 }}`. Use `hasKey` before optional fields such as `url`, `headers`, `command`, and `args` to avoid missing-key render failures.

- [ ] **Step 3: Verify APM template tests pass**

Run: `mise exec -- bats tests/template/apm-config.bats`

Expected: PASS, 3 tests.

- [ ] **Step 4: Verify existing APM install script tests pass**

Run: `mise exec -- bats tests/template/install-apm-script.bats`

Expected: PASS, existing tests.

### Task 3: Verification and PR

**Files:**

- Verify: `home/.chezmoidata/apm.yaml`
- Verify: `home/.chezmoitemplates/apm/mcp-server.yml.tmpl`
- Verify: `home/dot_apm/apm.yml.tmpl`
- Verify: `tests/template/apm-config.bats`
- Verify: `docs/superpowers/specs/2026-05-20-work-apm-mcp-data-design.md`

- [ ] **Step 1: Run formatting and checks**

Run: `mise format && mise check`

Expected: formatting completes, Prettier passes, shell lint passes, taplo passes, unit Bats tests pass, and template Bats tests pass.

- [ ] **Step 2: Render work APM config and inspect key lines**

Run: `mise exec -- chezmoi execute-template --source home --override-data '{"chezmoi":{"os":"darwin"},"personal":false,"work":true}' < home/dot_apm/apm.yml.tmpl`

Expected output includes `name: figma`, `Authorization: "Bearer ${FIGMA_TOKEN}"`, `name: atlassian-jira`, `name: atlassian-knowledge`, `"${ATLASSIAN_JIRA_RESOURCE_URL}"`, and `"${ATLASSIAN_KNOWLEDGE_RESOURCE_URL}"`.

Expected output does not include `atlassian_resource_url` or `${input:figma-token}`.

- [ ] **Step 3: Commit implementation**

Run: `git add docs/superpowers/plans/2026-05-20-work-apm-mcp-data.md docs/superpowers/specs/2026-05-20-work-apm-mcp-data-design.md home/.chezmoidata/apm.yaml home/.chezmoitemplates/apm/mcp-server.yml.tmpl home/dot_apm/apm.yml.tmpl tests/template/apm-config.bats && git diff --cached --check && git commit -m "feat: render work APM MCP servers from data"`

- [ ] **Step 4: Push and create PR**

Push `apm/work-mcp-data`, create a PR titled `Render work APM MCP servers from data`, include `Closes #41`, self-assign it, and verify PR checks.
