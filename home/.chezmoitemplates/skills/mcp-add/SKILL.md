---
name: mcp-add
description: Use when adding, configuring, or debugging an MCP server (project .mcp.json or user scope), when a server needs auth tokens or OAuth, or when MCP tools do not appear after setup.
---

# MCP Add

## Overview

Adding an MCP server fails at auth and verification, not config syntax. Own the whole loop: pick scope, write config, drive auth, verify tools appear. Never end with "set it up and try again".

## Scope decision

| Scope               | Where                                                           | Use for                                                |
| ------------------- | --------------------------------------------------------------- | ------------------------------------------------------ |
| Project             | `.mcp.json` in repo root                                        | Servers tied to one codebase (committed, team-visible) |
| User (this machine) | `claude mcp add --scope user`                                   | Personal servers across repos                          |
| Every machine       | `home/.chezmoidata/ai.yaml` `mcp:` section in the dotfiles repo | Servers chezmoi should install everywhere              |

Before adding: confirm the server is the vendor's official one (URL on the vendor's domain or GitHub org). State which entry you chose and why; third-party clones of official servers are a known trap. Vendors often ship both a hosted OAuth server and a token-based package; pick by the auth method the user has or prefers.

## Steps

1. Write the config yourself (edit `.mcp.json` or run `claude mcp add`). HTTP servers: `{"type": "http", "url": "..."}` with token headers as `"Authorization": "Bearer ${TOKEN_VAR}"`. Stdio servers: `claude mcp add <name> --env TOKEN_VAR='${TOKEN_VAR}' -- npx -y <package>`.
2. Token servers: give the user two exact commands: append the export to their shell env file (`~/.zshrc` here), then restart Claude Code. `${VAR}` expands at startup; a mid-session export never reaches the server.
3. OAuth servers: tell the user to run `/mcp` and authenticate there.
4. Pause until the user confirms the auth or restart is done, then verify before claiming done: `claude mcp list` shows the server connected, and ToolSearch finds its tools. Not connected: read the error, fix, re-verify.
5. Report server name, scope, and tool count.

## Common mistakes

| Mistake                                                  | Fix                       |
| -------------------------------------------------------- | ------------------------- |
| "Config written, try again" with no verification         | Step 4 is mandatory       |
| Third-party clone instead of official server             | Check vendor domain first |
| Expecting `${VAR}` to resolve after a mid-session export | Needs a session restart   |
| User-scope entry for a project-specific server           | Use the scope table       |
