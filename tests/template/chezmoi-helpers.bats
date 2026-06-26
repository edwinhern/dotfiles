#!/usr/bin/env bats
# @file tests/template/chezmoi-helpers.bats
# @brief Template rendering tests for chezmoi helper templates.

load '../test_helpers/load.bash'

SOURCE_DIR="$DOTFILES_ROOT/home"
ACTIVE_GROUPS_TMPL="$DOTFILES_ROOT/home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl"
ACTIVE_GROUP_VALUES_TMPL="$DOTFILES_ROOT/home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl"

DARWIN_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":false}'
WORK_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":true}'
SHARED_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":false}'

APM_VALUES_BY_GROUP='{"shared":[],"personal":["claude","agent-skills"],"work":["copilot"]}'

render_helper() {
  local template="$1"
  local data="$2"

  mise exec -- chezmoi execute-template --source "$SOURCE_DIR" --override-data "$data" <"$template"
}

@test "active-groups returns shared and personal for personal context" {
  run render_helper "$ACTIVE_GROUPS_TMPL" "$DARWIN_DATA"

  assert_success
  assert_output '["shared","personal"]'
}

@test "active-groups returns shared and work for work context" {
  run render_helper "$ACTIVE_GROUPS_TMPL" "$WORK_DATA"

  assert_success
  assert_output '["shared","work"]'
}

@test "active-groups returns only shared when neither personal nor work" {
  run render_helper "$ACTIVE_GROUPS_TMPL" "$SHARED_DATA"

  assert_success
  assert_output '["shared"]'
}

@test "active-group-values merges shared and personal apm targets for personal context" {
  local data
  data=$(printf '{"ctx":{"personal":true,"work":false},"valuesByGroup":%s}' "$APM_VALUES_BY_GROUP")

  run render_helper "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '["claude","agent-skills"]'
}

@test "active-group-values merges shared and work apm targets for work context" {
  local data
  data=$(printf '{"ctx":{"personal":false,"work":true},"valuesByGroup":%s}' "$APM_VALUES_BY_GROUP")

  run render_helper "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '["copilot"]'
}

@test "active-group-values returns only shared apm targets when neither personal nor work" {
  local data
  data=$(printf '{"ctx":{"personal":false,"work":false},"valuesByGroup":%s}' "$APM_VALUES_BY_GROUP")

  run render_helper "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '[]'
}
