# Repo Refine and Cleanup Plan

> **For agentic workers:** execute task-by-task. Each task lists exact files, the change, and how to verify it. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Refine, clean up, and simplify the chezmoi dotfiles repo without changing applied behavior, aligned with the in-flight apm to ai migration (DOT-43).

**Architecture:** Two adversarially-verified reviews (structure-research and kaizen-review) plus a direct `mise.toml` analysis produced this task set. Most of the structure is already sound and is deliberately kept. Changes are small, mostly single-file, and each is verified rendering-equivalent before it lands.

**Tech Stack:** chezmoi (`.chezmoiroot=home`), Go templates, POSIX/bash install libs, mise tasks, treefmt/shfmt/shellcheck/prettier/taplo, bats.

---

## Verified: kept as-is (do NOT touch)

These were evaluated and deliberately left alone. Reasons recorded so they are not re-litigated.

- **`booleans -> active-groups -> active-group-values` layering.** Correct primitive (3+ consumers, single source of truth for the personal/work mapping); the two-template split maps to two real data shapes. Self-describing names. No simpler equivalent preserves the scoping.
- **`.chezmoitemplates/lib/` split** (`lib/chezmoi` template helpers vs `lib/{common,darwin,install}` shell libs). chezmoi imposes no internal convention and there is none in the community; the split already separates the two kinds. Renaming is churn.
- **`active-group-values.json.tmpl`.** Not dead code: one live consumer today, nil-safe, bats-tested, gains consumers in the migration.
- **`lib/darwin/defaults.sh` dock layout duplication.** Ordered config list where explicit per-layout order aids readability; extracting the shared middle would obscure dock order.
- **`chezmoiignore.d/darwin` empty fragment.** Deliberate extension point mirroring the populated `chezmoiexternal.d/`; cheap ceremony.
- **Data-hash `# <file> hash` comments** on scripts that inline their data. Redundant but harmless; removing risks silent onchange breakage on a future refactor.
- **Empty-skip guards** (`$hasTools`, `len platforms > 0`) present only on installers whose active set can legitimately be empty. Correct as-is; new migration installers with possibly-empty groups should copy the guarded pattern.

---

## Group A: structure cleanups (migration-independent, safe now)

### Task A1: Route the vscode installer through the tested helper

**Files:**

- Modify: `home/.chezmoiscripts/darwin/run_onchange_04_install-vscode-extensions.sh.tmpl`

The inline `range .vscode.shared` + `if .personal` + `if .work` fan-out is the one place the group-selection idiom is hand-rolled a third way. `.vscode` has the identical scalar-list-per-group shape as `.ai.targets`, which `run_onchange_08` already flattens via the helper.

- [ ] Replace the inline fan-out with:
      `{{- $ext := includeTemplate "lib/chezmoi/active-group-values.json.tmpl" (dict "ctx" . "valuesByGroup" .vscode) | fromJson -}}`
      then render `VSCODE_EXTENSIONS=( {{ range $ext }}"{{ . }}" {{ end }} )`.
- [ ] Verify rendering-equivalent: `chezmoi execute-template < <file>` before/after produce the same `VSCODE_EXTENSIONS` array (order shared -> personal -> work preserved; only cosmetic per-group `# shared` comments are lost).
- [ ] The onchange hash is over `extensions.yaml` (unchanged), so no spurious re-run.

### Task A2: Generalize the `AGENTS.md` template to be provider-neutral (keep the name)

**Files:**

- Modify: `home/.chezmoitemplates/AGENTS.md` (H1 + intro line only)

Decision: KEEP the filename `AGENTS.md` — it is the cross-provider standard, so the same guidance can feed Claude (`~/.claude/CLAUDE.md`), Copilot (`AGENTS.md`), and any future agent. No rename. The name "collision" with the repo-root `AGENTS.md` is human-readability only; `{{ template "AGENTS.md" }}` resolves unambiguously to the `.chezmoitemplates/` file, so it costs nothing. Fix the content instead: the body (AI Guidance, GitHub CLI, Git/PR workflow, Graphify) is already provider-neutral; only the top two lines name Claude.

- [ ] Line 1: `# Claude Code Settings` -> `# Agent Guidance` (or `# AI Agent Guidance`).
- [ ] Line 3: `Guidance for Claude Code and other AI tools.` -> `Guidance for AI coding agents (Claude Code, GitHub Copilot, and others).`
- [ ] Leave the rest of the body unchanged; it is already agnostic.
- [ ] Verify: `chezmoi execute-template < home/dot_claude/CLAUDE.md.tmpl` still renders the full guidance body (the `{{ template "AGENTS.md" . }}` reference is untouched).
- [ ] Cross-agent wiring (feeding this same template to Copilot's `AGENTS.md`) is handled in the DOT-43 migration's instructions design, not here.

### Task A3: Rename `extensions.yaml` -> `vscode.yaml` for filename==key uniformity

**Files:**

- Rename: `home/.chezmoidata/extensions.yaml` -> `home/.chezmoidata/vscode.yaml`
- Modify: `home/.chezmoiscripts/darwin/run_onchange_04_install-vscode-extensions.sh.tmpl` (hash-comment path only)

Every other data file matches filename to its single top-level key (`packages`, `ai`, `mise`, `uv`); `extensions.yaml` is the lone outlier (key is `vscode:`). Renaming the file (not the key) keeps the `.vscode` accessor untouched. Included here because Group A is already touching this script and this completes the convention; skipped otherwise.

- [ ] `git mv` the data file.
- [ ] Update the hash comment `include ".chezmoidata/extensions.yaml"` -> `".chezmoidata/vscode.yaml"`.
- [ ] Verify: `chezmoi execute-template` on run_onchange_04 renders without error; one harmless `--force` re-run occurs because the hash-comment string changed.

---

## Group B: mise.toml and tooling simplification

### Task B1: Drop redundant `mise exec --` inside tasks

**Files:**

- Modify: `mise.toml` (all task `run` bodies)

Inside `mise run <task>`, the `[tools]` are already on `PATH`; `mise exec --` is redundant noise on every line.

- [ ] Confirm empirically first: `mise run diff` (or a trivial task) with `chezmoi` called bare works.
- [ ] Remove `mise exec -- ` prefixes from `diff`, `update`, `reset`, `reset-config`, `format`, `lint`, `test-*` task bodies.
- [ ] Verify: `mise lint` and `mise test` still run (leave CI's raw `run:` steps alone — those are outside a task env and keep `mise exec --`).

### Task B2: Adopt treefmt for format orchestration (DECIDED)

**Files:**

- Create: `treefmt.toml`
- Modify: `mise.toml` (`[tools]` add treefmt; rewrite `format`, shrink `lint`)

Replaces the two duplicated ~15-line shell-discovery bash blocks and the manual per-tool orchestration with one declarative config. `treefmt` walks the tree, respects each formatter's own ignore config, and dispatches shfmt/prettier/taplo. `shellcheck` stays a standalone lint step (treefmt is format-only).

- [ ] Add `treefmt = "2.5.0"` to `[tools]` via the aqua/ubi backend (`"aqua:numtide/treefmt" = "2.5.0"`).
- [ ] Create `treefmt.toml` with formatters: `shfmt` (`*.sh`, `*.zsh`, `.zshrc`; exclude `*.tmpl`), `prettier` (`*.md`, `*.yaml`, `*.yml`, `*.json`), `taplo fmt` (`*.toml`; exclude `*.tmpl`).
- [ ] `format` task -> `treefmt`.
- [ ] `lint` task -> `treefmt --ci` (fail on change) + the retained `shellcheck` block for `*.sh`/`*.zsh` and the `bats` shellcheck block.
- [ ] Verify: `mise format` then `git diff` shows no unexpected reformatting of `*.tmpl` files; `mise lint` passes on a clean tree.

### Task B3: Remove the retired apm dependency-management layer

**Files:**

- Modify: `mise.toml` (delete `[tasks.validate-apm]`, `[tasks.refresh-apm-locks]`)
- Delete: `tests/template/install-apm-script.bats`
- Modify: `.gitignore` (drop `# APM dependencies` + `apm_modules/`)

Keep the apm CLI (`home/.chezmoidata/mise.yaml` `github:microsoft/apm` + `Bash(apm:*)` permission). Only the dependency-management tasks/tests/artifacts go; their `scripts/*.sh` already do not exist.

- [ ] Delete the two apm tasks.
- [ ] Delete `install-apm-script.bats` (renders the already-removed apm script; would fail).
- [ ] Remove the `apm_modules/` gitignore lines.
- [ ] Verify: `mise test` passes (no apm bats failure); `command -v apm` still resolves.

---

## Group C: deferred INTO the DOT-43 migration

These are correct but must land inside the migration that is already restructuring `ai/` and reassigning script numbers, to avoid conflicting churn.

- **Rename `.chezmoitemplates/ai/skills/` -> `ai/instructions/`.** The six `*.instructions.md` files are GitHub Copilot custom-instructions (description+applyTo frontmatter), not skills; `skills` is currently overloaded three ways (ai.yaml `skills:` key, this dir, `dot_copilot/skills`). Zero references today, pure `git mv`. Settle the final name (`ai/instructions` vs `ai/copilot-instructions`) in the migration.
- **Give uv-tools a unique script number above mise-tools.** `uv-tools.sh` needs `mise` first (`require_command uv`); today the order holds only by `mise` < `uv` alphabetical accident within the shared `03` prefix. Assign a free number during the migration renumber (note: `04` is taken by vscode).
- **Holistic run-script renumbering.** After the migration adds plugins/skills/MCP scripts, renumber to be gapless and dependency-encoding.

---

## Execution approach

- Run as a team of subagents, one per task (or per group), each in an **isolated git worktree** so edits land on a reviewable branch, never the live working tree.
- Precondition: the working tree must be clean first — the in-flight `run_onchange_02` (taps) break and any uncommitted WIP resolved/committed — so worktrees branch from a coherent base and `chezmoi apply` / `mise lint` / `mise test` can verify cleanly.
- Verification gate per task: `chezmoi execute-template` on touched templates (rendering-equivalent), then `mise lint` and `mise test` green before the task is kept.

## Decisions (locked)

- **Tooling (Task B2): adopt treefmt.** One declarative `treefmt.toml` dispatches shfmt/prettier/taplo; `format = treefmt`, `lint = treefmt --ci` plus standalone `shellcheck`. Deletes both duplicated shell-discovery blocks. Accepts +1 mise tool and +1 config file.
- **Execution: clean tree first, then spin the team.** User resolves the `run_onchange_02` (taps) break and commits/stashes WIP; on confirmation, the worktree-isolated team executes Groups A + B against a coherent base with per-task verify gates. Group C lands inside the DOT-43 migration.
