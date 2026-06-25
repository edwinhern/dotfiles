# APM Reproducibility and Validation Design

**Status:** Draft for review (revised to a reproducibility-first approach).

**Linear issue:** [DOT-31](https://linear.app/edwinhern/issue/DOT-31/add-local-apm-validation)

## Goal

Make APM setup reproducible and verifiable. A `chezmoi apply` on any machine should install the exact same agent dependencies every time, and a single local-or-CI command should prove that the committed state reproduces without writing to the real home directory.

## Root Problem (why the original validation-only design was insufficient)

The first draft added a validation script but left the underlying reproducibility holes in place:

- APM dependencies in `home/.chezmoidata/apm.yaml` are floating refs (`obra/superpowers`, `JuliusBrussee/caveman`, ...) with no `#tag`/`#sha`. APM's own installer warns: _"dependencies unpinned ... add #tag or #sha to prevent drift."_
- No `apm.lock.yaml` is committed.
- The real run-script `home/.chezmoitemplates/lib/install/apm.sh` runs bare `apm install --global`, which re-resolves "whatever is on the default branch today" on every apply.

A validation that runs `apm install --global` then `apm install --global --frozen` against that just-generated lockfile only proves today's resolution is internally consistent. It cannot catch upstream drift, which is the actual risk. Reproducibility must be fixed upstream of validation.

## Confirmed APM 0.21.0 behavior

Verified against the pinned binary and `/microsoft/apm` docs:

- `apm install -g | --global` installs to user scope `~/.apm/`.
- `apm install --frozen` is the npm-ci-style gate: refuses to resolve, fails with status 1 when `apm.yml` and `apm.lock.yaml` have drifted, and requires the lockfile to be present.
- Dependency pinning syntax is `owner/repo#<tag|branch|sha>`.
- The lockfile lives at the project root next to `apm.yml`; for `--global` that is `~/.apm/apm.lock.yaml`. Docs say to always commit it.
- `apm audit` has no `--global` flag; audit is project-scope. `apm audit --ci` runs lockfile-consistency checks.
- Official recommended CI gate: `apm install --frozen` then `apm audit --ci`.
- Version caveat: in 0.21.0 `apm update` is deprecated and forwarded to `apm self-update` (the CLI binary updater), so it does not rewrite a lockfile. The command that re-resolves refs to latest SHAs and rewrites the user-scope lockfile is `apm lock --update --global`. (The `apm update` dependency-refresh behavior described in the upstream `main` docs is not in 0.21.0.)

## Approach (two layers)

APM uses the npm two-file model. The manifest ref is the update channel; the lockfile is the exact pin. Reproducibility comes from the committed lockfile plus `--frozen`, not from hard-pinning the manifest.

1. **Set each dependency's manifest ref as a channel** in `home/.chezmoidata/apm.yaml`: a release tag for upstreams that publish releases (moves only on a new tag), or the default branch for rolling repos. Do not hard-pin the manifest to a `#sha`; a fixed SHA is the "latest matching ref" forever, so `apm update` can never advance it. The exact SHA is recorded in the lockfile.
2. **Commit per-context lockfiles.** Because `apm.yml` is context-templated (personal and work differ), generate one lockfile per context and commit both. The lockfile holds the resolved SHA and content hash, so it is the reproducibility pin.
3. **Switch the real run-script** `home/.chezmoitemplates/lib/install/apm.sh` to `apm install --global --frozen` so `chezmoi apply` reproduces the locked SHAs instead of re-resolving.

Drift control: `apm install --frozen` exits non-zero when manifest and lockfile disagree, so between updates every apply installs the exact locked SHAs and nothing drifts.

### Layer 2 - Validation

Keep the well-designed mechanics from the first draft and point the gate at the committed lockfile:

- One repo-owned entrypoint `scripts/validate-apm.sh` accepting `personal`, `work`, or `all` (default `all`).
- For each context: create a temp root and temp home, write the CI chezmoi stub config, then apply only the `~/.apm` target into the temp home so reproducible files (including the lockfile) land via the real source-to-target mapping without firing run scripts.
- Run the gate in an isolated temp home: `apm install --global --frozen` then `apm audit --ci`. The frozen install proves the committed lockfile matches the committed (templated) `apm.yml`; the audit checks lockfile consistency.

## File Organization

```
home/.chezmoidata/apm.yaml                        # deps pinned by #tag/#sha (source of truth)
home/dot_apm/apm.yml.tmpl                          # unchanged, context-templated manifest
home/.chezmoitemplates/apm/apm.lock.personal.yaml  # committed lockfile, not a deploy target
home/.chezmoitemplates/apm/apm.lock.work.yaml      # committed lockfile, not a deploy target
home/dot_apm/apm.lock.yaml.tmpl                    # selects the context lockfile -> ~/.apm/apm.lock.yaml
home/.chezmoitemplates/lib/install/apm.sh          # runtime: apm install --global --frozen
scripts/apm-lib.sh                                 # shared: materialize a context's ~/.apm into a temp home
scripts/validate-apm.sh                            # dev/CI validation entrypoint (sources apm-lib.sh)
scripts/refresh-apm-locks.sh                       # regenerate committed lockfiles (sources apm-lib.sh)
mise.toml                                          # validate-apm[-personal|-work] + refresh-apm-locks tasks
.github/workflows/ci.yaml                          # validate_apm job calls the mise task
```

This preserves the repo's existing split: `lib/install/` holds runtime libraries injected into chezmoi run-scripts; `scripts/` holds dev/CI tooling (already a lint root in `mise.toml`). Lockfiles live under `.chezmoitemplates/` so chezmoi never deploys them as their own target files; `apm.lock.yaml.tmpl` selects the right one:

```gotemplate
{{- if .personal }}{{ includeTemplate "apm/apm.lock.personal.yaml" . }}
{{- else if .work }}{{ includeTemplate "apm/apm.lock.work.yaml" . }}{{ end -}}
```

## Lockfile Generation (`refresh-apm-locks`)

`scripts/refresh-apm-locks.sh` regenerates the committed lockfiles when dependencies change. For each context it renders `apm.yml` into a temp `~/.apm`, runs `apm lock --update --global` (re-resolve refs to latest SHAs and rewrite the lockfile) to produce `~/.apm/apm.lock.yaml`, then copies that file back to `home/.chezmoitemplates/apm/apm.lock.<context>.yaml`.

The temp-home materialization (resolve pinned tools, write stub config, `chezmoi apply` the `~/.apm` target) is identical to what validation needs, so it lives once in `scripts/apm-lib.sh` and is sourced by both `scripts/validate-apm.sh` and `scripts/refresh-apm-locks.sh`. The scheduled `apm_update` CI workflow calls `refresh-apm-locks.sh` rather than re-implementing the loop. This keeps a single materialization implementation, the same anti-drift principle applied to the validation entrypoint. Both scripts resolve pinned tool paths before changing `HOME` (see Script Safety Rules) and never touch the real home directory.

Note: the lockfile carries a `generated_at` timestamp, so regeneration produces a diff even when resolved commits are unchanged. That is expected.

## Chezmoi Materialization (validation)

For each context the validation script resolves pinned tools first, then writes the stub config and applies only the `~/.apm` target:

```sh
chezmoi_bin="$(mise which chezmoi)"
apm_bin="$(mise which apm)"

HOME="$tmp_home" "$repo/.github/actions/write-chezmoi-config/write-chezmoi-config.sh" "$context"

"$chezmoi_bin" apply \
  --source "$repo" \
  --destination "$tmp_home" \
  --config "$tmp_home/.config/chezmoi/chezmoi.yaml" \
  --config-format yaml \
  --persistent-state "$tmp_root/chezmoistate-$context.boltdb" \
  --cache "$tmp_root/cache-$context" \
  --refresh-externals=never \
  --include files,dirs \
  --no-tty \
  "$tmp_home/.apm"
```

`--include files,dirs` (omitting `scripts`) is what keeps Darwin run scripts from firing while still using the real source-to-target mapping. After apply, verify these exist: `$tmp_home/.apm/apm.yml`, `$tmp_home/.apm/.apm`, and `$tmp_home/.apm/apm.lock.yaml`.

## APM Validation Gate

Run with user-scope semantics and isolated XDG paths:

```sh
HOME="$tmp_home" \
XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
"$apm_bin" install --global --frozen --parallel-downloads 0

HOME="$tmp_home" \
XDG_CACHE_HOME="$tmp_home/.cache" XDG_CONFIG_HOME="$tmp_home/.config" XDG_STATE_HOME="$tmp_home/.local/state" \
"$apm_bin" audit --ci --no-policy
```

The frozen install fails if the committed lockfile drifted from the committed manifest. The audit checks lockfile consistency. If either exits non-zero, validation for that context fails.

## `all` semantics

`scripts/validate-apm.sh all` must run both contexts and report each independently, then exit non-zero if any failed. Do not let `set -e` short-circuit the loop after the first failure; capture each context exit code, print a labeled pass/fail line per context, and aggregate. This satisfies the requirement to show whether `personal` or `work` failed.

## Mise Tasks

- `validate-apm-personal`: `scripts/validate-apm.sh personal`.
- `validate-apm-work`: `scripts/validate-apm.sh work`.
- `validate-apm`: `scripts/validate-apm.sh all`.
- `refresh-apm-locks`: regenerate both committed lockfiles.

Keep these explicit; APM validation is networked and slower than template or unit tests, so it is not added to `mise check` by default.

## Update Lifecycle and Automation

Updates and reproducibility are separate concerns served by separate commands:

- `apm install --global --frozen` (runtime apply and the CI gate) never fetches newer code; it installs the lockfile's resolved SHAs.
- `apm lock --update --global` re-resolves each manifest ref to its latest matching SHA and rewrites the lockfile. This is the command that advances versions in 0.21.0 (not `apm update`, which forwards to `self-update`).

Local refresh loop (human, when intentionally updating):

```sh
apm lock --update --global       # re-resolve refs + rewrite ~/.apm/apm.lock.yaml
apm install --global --frozen    # materialize the new lockfile
apm audit --ci --no-policy       # confirm integrity
```

Dependabot does not understand APM, so split responsibilities:

- Keep Dependabot for the GitHub Actions ecosystem it already manages (`actions/checkout`, `jdx/mise-action`, ...) via `.github/dependabot.yaml`.
- Add a scheduled `apm_update` GitHub Actions workflow as the APM analog. On a weekly cron it runs `refresh-apm-locks` (which calls `apm lock --update --global` per context in an isolated temp home and copies the regenerated lockfiles back into the chezmoi source) and opens a pull request only when a lockfile changed. The PR triggers the normal `validate_apm` job, so `apm install --frozen` + `apm audit --ci` gate the refresh before a human reviews and merges. Agent dependencies change assistant behavior, so the merge stays manual.

This gives a Dependabot-style "here is what moved" PR flow while keeping the `--frozen` reproducibility gate on the update itself.

## CI Design

Update the `validate_apm` job so each matrix entry calls the shared entrypoint instead of owning custom render, copy, and install steps:

```yaml
matrix:
  context: [personal, work]
```

```sh
mise validate-apm-${{ matrix.context }}
```

This ties local and CI behavior to one script and removes the project-copy hack currently in the workflow.

APM validation is networked (a `--frozen` install still fetches the locked SHAs). Cache the APM cache directory keyed on a hash of the committed lockfiles so unchanged locks skip re-fetching. Use `apm audit --ci --no-policy`; org policy is experimental and irrelevant here.

## Out of Scope

- Adding networked APM validation to `mise check` by default.
- Changing APM MCP server definitions or the set of dependencies (only their pins change).
- Org-policy audit (`apm audit --policy`); `--no-policy` is used.
- Full drift audit as the primary gate; the `--frozen` install is the primary gate, `apm audit --ci` is the secondary consistency check.

## Script Safety Rules

- `set -euo pipefail`; shdoc-compatible English comments.
- Create temp dirs with `mktemp -d`; remove them via a trap unless `DOTFILES_KEEP_APM_VALIDATION_TMP` is set.
- Never run a broad `chezmoi apply`; always target `~/.apm`.
- Never set `HOME` before resolving the pinned `chezmoi` and `apm` binaries.
- Print context labels so a reader can see whether `personal` or `work` failed.

## Validation Plan

- Pin deps, regenerate both lockfiles with `mise refresh-apm-locks`, commit them.
- Run `mise validate-apm-personal`, `mise validate-apm-work`, and `mise validate-apm`.
- Confirm a deliberately edited lockfile makes `--frozen` fail (negative test).
- Run `mise test-template` so existing APM template tests still pass, plus a new test for `apm.lock.yaml.tmpl` context selection.
- Run `mise lint` so the new script passes shellcheck and shfmt.

## Acceptance Criteria

- Each APM dependency manifest ref is a deliberate channel (release tag or default branch), not a hard SHA.
- Per-context `apm.lock.yaml` files are committed and selected correctly by context, and are the reproducibility pin.
- A scheduled `apm_update` workflow opens a PR when `apm update --yes` changes a lockfile, and that PR is gated by the `--frozen` validation.
- Dependabot continues to manage the GitHub Actions ecosystem; APM updates are handled by the scheduled workflow.
- The real run-script installs with `--frozen`, so `chezmoi apply` reproduces the locked state.
- One local command validates each context; `all` runs both and reports each.
- CI uses the same entrypoint as local development.
- Validation uses chezmoi to create `~/.apm` (manifest and lockfile) rather than manually rendering and copying.
- Validation never writes to the real home directory and never runs Homebrew, APM install scripts, or other chezmoi run scripts while preparing the temp home.
