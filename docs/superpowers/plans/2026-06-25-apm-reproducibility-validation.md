# APM Reproducibility and Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make APM dependency installs reproducible (committed per-context lockfiles + `--frozen`) and verifiable through one local-and-CI entrypoint, plus a scheduled APM update PR bot.

**Architecture:** APM follows the npm two-file model: the manifest ref (`apm.yml`, templated per context) is the update channel; the committed `apm.lock.yaml` is the exact pin. The real chezmoi run-script and CI both install with `--frozen` so every apply reproduces the locked SHAs. A shared shell library (`scripts/apm-lib.sh`) materializes a context's `~/.apm` into an isolated temp home; both the validation entrypoint and the lockfile-refresh script source it. A scheduled workflow runs `apm update --yes` and opens a gated PR.

**Tech Stack:** chezmoi, APM 0.21.0, Bash, bats (bats-support/bats-assert/bats-file), mise, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-06-24-local-apm-validation-design.md`

---

## File Map

- Modify `home/.chezmoidata/apm.yaml`: add a channel ref (`#<tag|branch>`) to each dependency.
- Create `home/.chezmoitemplates/apm/apm.lock.personal.yaml`, `apm.lock.work.yaml`: committed lockfiles (generated, not hand-written).
- Create `home/dot_apm/apm.lock.yaml.tmpl`: selects the context lockfile into `~/.apm/apm.lock.yaml`.
- Modify `home/.chezmoitemplates/lib/install/apm.sh`: install with `--global --frozen`.
- Modify `tests/unit/lib/install/apm.bats`: assert the frozen flag.
- Create `scripts/apm-lib.sh`: shared tool resolution + temp-home `~/.apm` materialization.
- Create `scripts/validate-apm.sh`: per-context frozen install + audit, `all` aggregation.
- Create `scripts/refresh-apm-locks.sh`: regenerate committed lockfiles via `apm update --yes`.
- Create `tests/unit/scripts/apm-lib.bats`, `tests/unit/scripts/validate-apm.bats`: behavior tests with stubbed `chezmoi`/`apm`.
- Create `tests/template/apm-lockfile.bats`: context selection of `apm.lock.yaml.tmpl`.
- Modify `mise.toml`: add `validate-apm*`, `refresh-apm-locks` tasks.
- Modify `.github/workflows/ci.yaml`: rewire `validate_apm` to the mise task + cache.
- Create `.github/workflows/apm-update.yaml`: scheduled `apm update` PR bot.

No commit steps run unless the user asks; each task ends with a commit step the executor may skip per session policy.

---

### Task 1: Pin dependency channels in apm.yaml

APM warns that unpinned refs drift. Set a deliberate channel per dependency: a release tag where the upstream publishes releases, else the default branch. The exact SHA is captured later in the lockfile.

**Files:**
- Modify: `home/.chezmoidata/apm.yaml`

- [ ] **Step 1: Discover each dependency's newest tag (empty output means no releases - use the default branch)**

Run:
```bash
for repo in obra/superpowers JuliusBrussee/caveman anthropics/claude-plugins-official schpet/linear-cli tavily-ai/skills JuliusBrussee/skills; do
  printf '%s -> ' "$repo"
  gh api "repos/$repo/tags" --jq '.[0].name' 2>/dev/null || echo "(no tags)"
done
```
Expected: one line per repo, either a tag like `v1.2.3` or `(no tags)`/empty.

- [ ] **Step 2: Determine each repo's default branch (used when no tag exists)**

Run:
```bash
for repo in obra/superpowers JuliusBrussee/caveman anthropics/claude-plugins-official schpet/linear-cli tavily-ai/skills JuliusBrussee/skills; do
  printf '%s -> ' "$repo"; gh api "repos/$repo" --jq '.default_branch'
done
```
Expected: one branch name per repo (e.g. `main`).

- [ ] **Step 3: Edit `home/.chezmoidata/apm.yaml` to append `#<ref>` to each dependency**

Use the tag from Step 1 if present, else the branch from Step 2. String deps become `owner/repo#<ref>`; the map dep keeps its shape with the ref on the git line. Example shape (substitute the refs you resolved):

```yaml
  dependencies:
    shared:
      - obra/superpowers#<ref>
      - JuliusBrussee/caveman#<ref>
      - anthropics/claude-plugins-official/plugins/skill-creator#<ref>
    personal:
      - schpet/linear-cli#<ref>
      - tavily-ai/skills#<ref>
      - git: JuliusBrussee/skills#<ref>
        skills:
          - grill-me
          - junior-to-senior
    work: []
```

Leave `apm.targets` and `apm.mcp` unchanged.

- [ ] **Step 4: Verify both contexts still render valid YAML with refs present**

Run:
```bash
echo "== personal =="; mise exec -- chezmoi execute-template --source home \
  --override-data '{"personal":true,"work":false}' < home/dot_apm/apm.yml.tmpl | grep -E '^\s+- '
echo "== work =="; mise exec -- chezmoi execute-template --source home \
  --override-data '{"personal":false,"work":true}' < home/dot_apm/apm.yml.tmpl | grep -E '^\s+- '
```
Expected: rendered dependency lines all carry `#<ref>`.

- [ ] **Step 5: Commit**

```bash
git add home/.chezmoidata/apm.yaml
git commit -m "feat: DOT-31 pin APM dependency channels"
```

---

### Task 2: Shared materialization library `scripts/apm-lib.sh`

One implementation of "resolve pinned tools, then materialize a context's `~/.apm` into a temp home" used by both validation and lockfile refresh.

**Files:**
- Create: `scripts/apm-lib.sh`
- Test: `tests/unit/scripts/apm-lib.bats`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/scripts/apm-lib.bats`:

```bash
#!/usr/bin/env bats
# @file tests/unit/scripts/apm-lib.bats
# @brief Behavior tests for scripts/apm-lib.sh shared materialization.

load '../../test_helpers/load.bash'

LIB="$DOTFILES_ROOT/scripts/apm-lib.sh"

setup() {
  export ARGS_FILE="$BATS_TEST_TMPDIR/chezmoi-args"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat >"$BATS_TEST_TMPDIR/bin/chezmoi" <<'CHEZMOI'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ARGS_FILE"
CHEZMOI
  chmod +x "$BATS_TEST_TMPDIR/bin/chezmoi"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # apm_lib resolves tools via `mise which`; stub it to our fake binaries.
  cat >"$BATS_TEST_TMPDIR/bin/mise" <<'MISE'
#!/usr/bin/env bash
if [ "$1" = "which" ]; then echo "$BATS_TEST_TMPDIR/bin/$2"; fi
MISE
  chmod +x "$BATS_TEST_TMPDIR/bin/mise"
}

@test "apm_lib_resolve_bins sets CHEZMOI_BIN and APM_BIN before HOME changes" {
  run bash -c "source '$LIB' && apm_lib_resolve_bins && echo \"\$CHEZMOI_BIN|\$APM_BIN\""
  assert_success
  assert_output --partial "/bin/chezmoi|"
  assert_output --partial "/bin/apm"
}

@test "apm_lib_materialize applies only the ~/.apm target with scripts excluded" {
  run bash -c "
    source '$LIB'
    CHEZMOI_BIN='$BATS_TEST_TMPDIR/bin/chezmoi'
    apm_lib_materialize personal '$BATS_TEST_TMPDIR/root' '$BATS_TEST_TMPDIR/home' '$DOTFILES_ROOT'
  "
  assert_success
  run cat "$ARGS_FILE"
  assert_output --partial "apply"
  assert_output --partial "--include files,dirs"
  assert_output --partial "/home/.apm"
  refute_output --partial "scripts"
}
```

- [ ] **Step 2: Run the failing test**

Run: `mise exec -- bats tests/unit/scripts/apm-lib.bats`
Expected: FAIL because `scripts/apm-lib.sh` does not exist.

- [ ] **Step 3: Implement `scripts/apm-lib.sh`**

```bash
#!/usr/bin/env bash
# @file scripts/apm-lib.sh
# @brief Shared helpers to materialize a context's ~/.apm into a temp home.
# @description
#   Sourced by scripts/validate-apm.sh and scripts/refresh-apm-locks.sh.
#   Resolves pinned tool paths before HOME is changed, then applies only the
#   ~/.apm chezmoi target into an isolated temp home without firing run scripts.

set -Eeuo pipefail

# @description Resolve pinned chezmoi and apm binaries. Call before changing HOME,
#   because an isolated HOME breaks mise trust resolution.
# @set CHEZMOI_BIN Absolute path to the pinned chezmoi binary.
# @set APM_BIN Absolute path to the pinned apm binary.
function apm_lib_resolve_bins() {
  CHEZMOI_BIN="$(mise which chezmoi)"
  APM_BIN="$(mise which apm)"
  export CHEZMOI_BIN APM_BIN
}

# @description Materialize ~/.apm for a context into a temp home.
# @arg $1 string Context: personal or work.
# @arg $2 string Temp root for chezmoi state and cache.
# @arg $3 string Temp home directory.
# @arg $4 string Repo root (chezmoi source parent).
function apm_lib_materialize() {
  local context="$1" tmp_root="$2" tmp_home="$3" repo="$4"

  HOME="$tmp_home" "$repo/.github/actions/write-chezmoi-config/write-chezmoi-config.sh" "$context"

  "${CHEZMOI_BIN}" apply \
    --source "$repo/home" \
    --destination "$tmp_home" \
    --config "$tmp_home/.config/chezmoi/chezmoi.yaml" \
    --config-format yaml \
    --persistent-state "$tmp_root/chezmoistate-$context.boltdb" \
    --cache "$tmp_root/cache-$context" \
    --refresh-externals=never \
    --include files,dirs \
    --no-tty \
    "$tmp_home/.apm"
}
```

- [ ] **Step 4: Run the tests**

Run: `mise exec -- bats tests/unit/scripts/apm-lib.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/apm-lib.sh tests/unit/scripts/apm-lib.bats
git commit -m "feat: DOT-31 add shared apm materialization library"
```

---

### Task 3: Lockfile refresh script + initial committed lockfiles

**Files:**
- Create: `scripts/refresh-apm-locks.sh`
- Create: `home/.chezmoitemplates/apm/apm.lock.personal.yaml` (generated)
- Create: `home/.chezmoitemplates/apm/apm.lock.work.yaml` (generated)

- [ ] **Step 1: Implement `scripts/refresh-apm-locks.sh`**

```bash
#!/usr/bin/env bash
# @file scripts/refresh-apm-locks.sh
# @brief Regenerate committed per-context APM lockfiles.
# @description
#   For each context: materialize ~/.apm in a temp home, run
#   `apm lock --update --global` to re-resolve refs and rewrite apm.lock.yaml,
#   then copy the lockfile back to home/.chezmoitemplates/apm/apm.lock.<context>.yaml.
#   Never touches real HOME. Note: apm 0.21.0 forwards `apm update` to
#   `self-update` (binary updater), so `apm lock --update --global` is the command
#   that rewrites the user-scope lockfile at ~/.apm/apm.lock.yaml.

set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/apm-lib.sh
source "$repo/scripts/apm-lib.sh"

contexts=("${@:-personal work}")
[ "$#" -eq 0 ] && contexts=(personal work)

apm_lib_resolve_bins

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

for context in "${contexts[@]}"; do
  tmp_home="$tmp_root/home-$context"
  mkdir -p "$tmp_home"
  apm_lib_materialize "$context" "$tmp_root" "$tmp_home" "$repo"

  HOME="$tmp_home" \
  XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    "${APM_BIN}" lock --update --global

  cp "$tmp_home/.apm/apm.lock.yaml" "$repo/home/.chezmoitemplates/apm/apm.lock.$context.yaml"
  printf '[refresh] wrote home/.chezmoitemplates/apm/apm.lock.%s.yaml\n' "$context"
done
```

- [ ] **Step 2: Generate the lockfiles**

Run:
```bash
mkdir -p home/.chezmoitemplates/apm
bash scripts/refresh-apm-locks.sh
```
Expected: two `[refresh] wrote ...` lines, and two new lockfiles whose first line is `lockfile_version: '1'`.

- [ ] **Step 3: Verify the lockfiles look resolved**

Run: `grep -c resolved_commit home/.chezmoitemplates/apm/apm.lock.personal.yaml`
Expected: a non-zero count (one per resolved dependency).

- [ ] **Step 4: Commit**

```bash
git add scripts/refresh-apm-locks.sh home/.chezmoitemplates/apm/apm.lock.personal.yaml home/.chezmoitemplates/apm/apm.lock.work.yaml
git commit -m "feat: DOT-31 add lockfile refresh script and committed locks"
```

---

### Task 4: Deploy the right lockfile per context

**Files:**
- Create: `home/dot_apm/apm.lock.yaml.tmpl`
- Test: `tests/template/apm-lockfile.bats`

- [ ] **Step 1: Write the failing test**

Create `tests/template/apm-lockfile.bats`:

```bash
#!/usr/bin/env bats
# @file tests/template/apm-lockfile.bats
# @brief apm.lock.yaml.tmpl selects the correct per-context lockfile.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
TMPL="$DOTFILES_ROOT/home/dot_apm/apm.lock.yaml.tmpl"
PERSONAL='{"personal":true,"work":false}'
WORK='{"personal":false,"work":true}'

render() {
  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$1" <"$TMPL"
}

@test "personal context renders the personal lockfile" {
  personal_first="$(grep -m1 resolved_commit "$DOTFILES_ROOT/home/.chezmoitemplates/apm/apm.lock.personal.yaml")"
  run render "$PERSONAL"
  assert_success
  assert_output --partial "lockfile_version"
  assert_output --partial "$personal_first"
}

@test "work context renders the work lockfile" {
  run render "$WORK"
  assert_success
  assert_output --partial "lockfile_version"
}
```

- [ ] **Step 2: Run the failing test**

Run: `mise exec -- bats tests/template/apm-lockfile.bats`
Expected: FAIL because `home/dot_apm/apm.lock.yaml.tmpl` does not exist.

- [ ] **Step 3: Create `home/dot_apm/apm.lock.yaml.tmpl`**

```gotemplate
{{- if .personal -}}
{{ include ".chezmoitemplates/apm/apm.lock.personal.yaml" }}
{{- else if .work -}}
{{ include ".chezmoitemplates/apm/apm.lock.work.yaml" }}
{{- end -}}
```

Use `include` (raw file read relative to the source root), not `includeTemplate`, so the committed lockfile content is never evaluated as a Go template.

- [ ] **Step 4: Run the tests**

Run: `mise exec -- bats tests/template/apm-lockfile.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add home/dot_apm/apm.lock.yaml.tmpl tests/template/apm-lockfile.bats
git commit -m "feat: DOT-31 deploy per-context apm lockfile"
```

---

### Task 5: Make the runtime install reproducible

**Files:**
- Modify: `home/.chezmoitemplates/lib/install/apm.sh`
- Modify: `tests/unit/lib/install/apm.bats`

- [ ] **Step 1: Update the test to expect a frozen install**

In `tests/unit/lib/install/apm.bats`, the existing happy-path test asserts the recorded apm args. Change that assertion to expect the frozen global flags. The relevant assertion becomes:

```bash
  assert_output --partial "install --global --frozen"
```

Keep the existing stubbed-`apm` setup (a fake `apm` in `$BATS_TEST_TMPDIR/bin` recording `$*`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- bats tests/unit/lib/install/apm.bats`
Expected: FAIL because the lib still runs `apm install --global` without `--frozen`.

- [ ] **Step 3: Update `home/.chezmoitemplates/lib/install/apm.sh`**

Change the install line in `apm_install_main`:

```bash
function apm_install_main() {
  log_info "[apm] Installing globally from ~/.apm/apm.yml (frozen)..."
  cd "${HOME}/.apm"

  apm install --global --frozen || log_warn "[apm] apm install --frozen exited non-zero (lockfile drift or MCP token prompt in non-interactive shell)"

  log_info "[apm] Install complete."
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mise exec -- bats tests/unit/lib/install/apm.bats`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add home/.chezmoitemplates/lib/install/apm.sh tests/unit/lib/install/apm.bats
git commit -m "feat: DOT-31 install APM frozen for reproducible applies"
```

---

### Task 6: Validation entrypoint `scripts/validate-apm.sh`

**Files:**
- Create: `scripts/validate-apm.sh`
- Test: `tests/unit/scripts/validate-apm.bats`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/scripts/validate-apm.bats`:

```bash
#!/usr/bin/env bats
# @file tests/unit/scripts/validate-apm.bats
# @brief Behavior tests for scripts/validate-apm.sh argument handling and aggregation.

load '../../test_helpers/load.bash'

SCRIPT="$DOTFILES_ROOT/scripts/validate-apm.sh"

setup() {
  export CALL_FILE="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  # Stub mise (tool resolution), chezmoi (materialize), apm (gate).
  for t in mise chezmoi apm; do
    cat >"$BATS_TEST_TMPDIR/bin/$t" <<STUB
#!/usr/bin/env bash
echo "$t \$*" >>"$CALL_FILE"
if [ "$t" = mise ] && [ "\$1" = which ]; then echo "$BATS_TEST_TMPDIR/bin/\$2"; fi
exit "\${APM_EXIT:-0}"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/$t"
  done
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "all runs both contexts and reports each" {
  run bash "$SCRIPT" all
  assert_success
  assert_output --partial "personal: PASS"
  assert_output --partial "work: PASS"
}

@test "all reports both even when personal fails, exits non-zero" {
  export APM_EXIT=1   # exported so the stubbed apm (a grandchild process) sees it
  run bash "$SCRIPT" all
  assert_failure
  assert_output --partial "personal: FAIL"
  assert_output --partial "work: FAIL"
}

@test "rejects an unknown context" {
  run bash "$SCRIPT" bogus
  assert_failure
  assert_output --partial "Unsupported context"
}
```

- [ ] **Step 2: Run the failing test**

Run: `mise exec -- bats tests/unit/scripts/validate-apm.bats`
Expected: FAIL because `scripts/validate-apm.sh` does not exist.

- [ ] **Step 3: Implement `scripts/validate-apm.sh`**

```bash
#!/usr/bin/env bash
# @file scripts/validate-apm.sh
# @brief Validate APM reproducibility for one or both contexts in temp homes.
# @description
#   Materializes ~/.apm via chezmoi (manifest + committed lockfile), then runs
#   `apm install --global --frozen` and `apm audit --ci --no-policy` in an
#   isolated temp home. `all` runs both contexts and aggregates results.
# @arg $1 string Context: personal, work, or all (default all).

set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/apm-lib.sh
source "$repo/scripts/apm-lib.sh"

arg="${1:-all}"
case "$arg" in
personal | work) contexts=("$arg") ;;
all) contexts=(personal work) ;;
*)
  printf 'Unsupported context: %s (use personal, work, or all)\n' "$arg" >&2
  exit 1
  ;;
esac

apm_lib_resolve_bins

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# @description Run the frozen install + audit gate for one context.
# @arg $1 string Context.
# @return 0 on pass, non-zero on failure.
function validate_context() {
  local context="$1" tmp_home="$tmp_root/home-$1"
  mkdir -p "$tmp_home"
  apm_lib_materialize "$context" "$tmp_root" "$tmp_home" "$repo"

  HOME="$tmp_home" \
  XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    "${APM_BIN}" install --global --frozen --parallel-downloads 0
  HOME="$tmp_home" \
  XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
    "${APM_BIN}" audit --ci --no-policy
}

rc=0
for context in "${contexts[@]}"; do
  if validate_context "$context"; then
    printf '%s: PASS\n' "$context"
  else
    printf '%s: FAIL\n' "$context"
    rc=1
  fi
done
exit "$rc"
```

Note: the loop must not abort on the first failure. `validate_context` is called inside an `if`, which suppresses `set -e` for that call, so both contexts always run.

- [ ] **Step 4: Run the tests**

Run: `mise exec -- bats tests/unit/scripts/validate-apm.bats`
Expected: PASS.

- [ ] **Step 5: Run a real personal validation end-to-end**

Run: `bash scripts/validate-apm.sh personal`
Expected: `personal: PASS` (networked; needs the committed lockfile from Task 3).

- [ ] **Step 6: Negative test - prove the gate catches drift**

Run:
```bash
cp home/.chezmoitemplates/apm/apm.lock.personal.yaml /tmp/apm.lock.bak
printf '\n# tampered\n' >>home/.chezmoitemplates/apm/apm.lock.personal.yaml
bash scripts/validate-apm.sh personal; echo "exit=$?"
cp /tmp/apm.lock.bak home/.chezmoitemplates/apm/apm.lock.personal.yaml
```
Expected: `personal: FAIL` and `exit=1`, then the lockfile is restored.

- [ ] **Step 7: Commit**

```bash
git add scripts/validate-apm.sh tests/unit/scripts/validate-apm.bats
git commit -m "feat: DOT-31 add apm validation entrypoint"
```

---

### Task 7: Mise tasks

**Files:**
- Modify: `mise.toml`

- [ ] **Step 1: Add the tasks**

Append to `mise.toml`:

```toml
[tasks.validate-apm-personal]
description = "Validate APM reproducibility for the personal context"
run = "bash scripts/validate-apm.sh personal"

[tasks.validate-apm-work]
description = "Validate APM reproducibility for the work context"
run = "bash scripts/validate-apm.sh work"

[tasks.validate-apm]
description = "Validate APM reproducibility for both contexts"
run = "bash scripts/validate-apm.sh all"

[tasks.refresh-apm-locks]
description = "Re-resolve APM refs and rewrite committed lockfiles"
run = "bash scripts/refresh-apm-locks.sh"
```

- [ ] **Step 2: Verify the tasks are registered**

Run: `mise tasks ls | grep -E 'validate-apm|refresh-apm-locks'`
Expected: all four tasks listed.

- [ ] **Step 3: Commit**

```bash
git add mise.toml
git commit -m "feat: DOT-31 add apm validation and refresh mise tasks"
```

---

### Task 8: Rewire the CI validate_apm job

**Files:**
- Modify: `.github/workflows/ci.yaml`

- [ ] **Step 1: Replace the job body with the shared entrypoint + cache**

Replace the `validate_apm` job's steps (the `Render apm.yml` and `Audit APM project` steps) so each matrix entry calls the mise task, and cache the APM dir keyed on the committed lockfiles:

```yaml
  validate_apm:
    name: Validate APM config (${{ matrix.context }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        context: [personal, work]
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v4
      - name: Cache APM downloads
        uses: actions/cache@v4
        with:
          path: ~/.cache/apm
          key: apm-${{ runner.os }}-${{ hashFiles('home/.chezmoitemplates/apm/apm.lock.*.yaml') }}
      - name: Validate APM (${{ matrix.context }})
        run: mise validate-apm-${{ matrix.context }}
```

The script writes its own stub chezmoi config into a temp home, so the prior `write-chezmoi-config` action step is no longer needed in this job.

- [ ] **Step 2: Lint the workflow**

Run: `mise exec -- actionlint .github/workflows/ci.yaml || docker run --rm -v "$PWD":/repo --workdir /repo rhysd/actionlint:1.7.12 -color`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "feat: DOT-31 run apm validation through shared entrypoint in CI"
```

---

### Task 9: Scheduled APM update PR bot

**Files:**
- Create: `.github/workflows/apm-update.yaml`

- [ ] **Step 1: Create the workflow**

```yaml
name: APM update
on:
  schedule:
    - cron: "0 6 * * 1"
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  refresh-locks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v4
      - name: Refresh APM lockfiles
        run: mise refresh-apm-locks
      - name: Open PR if lockfiles changed
        uses: peter-evans/create-pull-request@v7
        with:
          branch: chore/apm-update
          title: Update APM lockfiles
          commit-message: "chore: DOT-31 refresh APM lockfiles"
          body: |
            Automated `apm update --yes` refresh of committed lockfiles.
            The validate_apm job gates this with `apm install --frozen`.
          add-paths: home/.chezmoitemplates/apm/apm.lock.*.yaml
```

- [ ] **Step 2: Lint the workflow**

Run: `docker run --rm -v "$PWD":/repo --workdir /repo rhysd/actionlint:1.7.12 -color .github/workflows/apm-update.yaml`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/apm-update.yaml
git commit -m "feat: DOT-31 add scheduled APM update PR bot"
```

---

### Task 10: Full verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run the full bats suite**

Run: `mise exec -- bats -r tests/`
Expected: all tests pass, including the new apm-lib, validate-apm, and apm-lockfile tests.

- [ ] **Step 2: Run lint**

Run: `mise lint`
Expected: shellcheck + shfmt pass on the new `scripts/*.sh`; markdown/yaml lint clean.

- [ ] **Step 3: Validate both contexts end-to-end**

Run: `mise validate-apm`
Expected: `personal: PASS` and `work: PASS`.

- [ ] **Step 4: Whitespace check**

Run: `git diff --check`
Expected: no output, exit 0.

---

## Notes for the executor

- APM dependencies change assistant behavior; the `apm_update` PR is reviewed and merged by a human, never auto-merged.
- `apm.lock.yaml` carries a `generated_at` timestamp, so `refresh-apm-locks` produces a diff even when resolved commits are unchanged. That is expected.
- The validation and refresh scripts are networked and slower than unit tests; they are intentionally not part of `mise check`.
