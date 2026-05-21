#!/usr/bin/env bash
# @file lib/install/opencode-agent-tools.sh
# @brief Normalise Claude-shaped `tools:` arrays in opencode agent files.
# @description
#   APM deploys agent files from claude-targeted packages (e.g.
#   `JuliusBrussee/caveman`) verbatim into opencode's agents dir.
#   Claude Code's agent schema accepts `tools: [Read, Grep, Bash]`,
#   but opencode requires `tools:` to be a YAML mapping of lowercase
#   tool keys to boolean values. This library rewrites inline-array
#   `tools:` lines in the YAML frontmatter into mapping form, in
#   place, byte-stable on every other line. Sourceable from bats
#   tests and injected into chezmoi run scripts via chezmoi template
#   rendering.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

#
# @description Rewrite one markdown file's frontmatter `tools:` array
#   (if any) into opencode's expected map form. Writes back in place.
# @arg $1 Path to the markdown file.
# @exitcode 0 File was modified.
# @exitcode 1 File was already in mapping form (or had no `tools:` line).
#
function opencode_agent_tools_normalize_file() {
  local path="$1"
  local tmp
  tmp="$(mktemp)"

  if awk '
    BEGIN { fm = 0; changed = 0 }
    {
      line = $0
      if (line == "---") {
        if (fm == 0) fm = 1
        else if (fm == 1) fm = 2
        print line
        next
      }
      if (fm == 1 && line ~ /^[ \t]*tools:[ \t]*\[[^]]*\][ \t]*$/) {
        tools_pos = index(line, "tools:")
        indent = substr(line, 1, tools_pos - 1)
        open_b = index(line, "[")
        close_b = index(line, "]")
        items_str = substr(line, open_b + 1, close_b - open_b - 1)
        n = split(items_str, items, ",")
        print indent "tools:"
        for (i = 1; i <= n; i++) {
          key = items[i]
          sub(/^[ \t\047"]+/, "", key)
          sub(/[ \t\047"]+$/, "", key)
          if (key == "") continue
          key = tolower(key)
          print indent "  " key ": true"
        }
        changed = 1
        next
      }
      print line
    }
    END { exit (changed ? 0 : 1) }
  ' "$path" >"$tmp"; then
    mv "$tmp" "$path"
    return 0
  fi

  rm -f "$tmp"
  return 1
}

#
# @description Normalise every `*.md` file in the given opencode agents
#   directory. No-ops when the directory does not exist.
# @arg $1 Path to the opencode agents directory.
#
function opencode_agent_tools_normalize_dir() {
  local agents_dir="$1"

  if [ ! -d "${agents_dir}" ]; then
    log_info "[opencode-fix] No agents dir at ${agents_dir}; nothing to do."
    return 0
  fi

  log_info "[opencode-fix] Normalising tools: frontmatter in ${agents_dir}"

  local touched=0
  local f
  for f in "${agents_dir}"/*.md; do
    [ -e "${f}" ] || continue
    if opencode_agent_tools_normalize_file "${f}"; then
      log_info "[opencode-fix] rewrote $(basename "${f}")"
      touched=$((touched + 1))
    fi
  done

  log_info "[opencode-fix] ${touched} file(s) updated."
}

#
# @description Run the normalisation flow against the default opencode dir.
#
function main() {
  opencode_agent_tools_normalize_dir "${HOME}/.config/opencode/agents"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
