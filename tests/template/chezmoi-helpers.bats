#!/usr/bin/env bats
# @file tests/template/chezmoi-helpers.bats
# @brief Template rendering tests for chezmoi helper templates.

load '../test_helpers/load.bash'
load '../test_helpers/templates.bash'

ACTIVE_GROUPS_TMPL="$DOTFILES_ROOT/home/.chezmoitemplates/lib/chezmoi/active-groups.json.tmpl"
ACTIVE_GROUP_VALUES_TMPL="$DOTFILES_ROOT/home/.chezmoitemplates/lib/chezmoi/active-group-values.json.tmpl"

SHARED_DATA='{"chezmoi":{"os":"darwin"},"personal":false,"work":false}'
BOTH_DATA='{"chezmoi":{"os":"darwin"},"personal":true,"work":true}'

APM_VALUES_BY_GROUP='{"shared":["graphify"],"personal":["claude","agent-skills"],"work":["copilot"]}'
APM_VALUES_SPARSE='{"shared":["graphify"]}'

@test "active-groups returns shared and personal for personal context" {
  run render_chezmoi_template "$ACTIVE_GROUPS_TMPL" "$DARWIN_DATA"

  assert_success
  assert_output '["shared","personal"]'
}

@test "active-groups returns shared and work for work context" {
  run render_chezmoi_template "$ACTIVE_GROUPS_TMPL" "$WORK_DATA"

  assert_success
  assert_output '["shared","work"]'
}

@test "active-groups returns only shared when neither personal nor work" {
  run render_chezmoi_template "$ACTIVE_GROUPS_TMPL" "$SHARED_DATA"

  assert_success
  assert_output '["shared"]'
}

@test "active-group-values merges shared and personal apm targets for personal context" {
  local data
  data=$(printf '{"ctx":{"personal":true,"work":false},"valuesByGroup":%s}' "$APM_VALUES_BY_GROUP")

  run render_chezmoi_template "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '["graphify","claude","agent-skills"]'
}

@test "active-group-values merges shared and work apm targets for work context" {
  local data
  data=$(printf '{"ctx":{"personal":false,"work":true},"valuesByGroup":%s}' "$APM_VALUES_BY_GROUP")

  run render_chezmoi_template "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '["graphify","copilot"]'
}

@test "active-group-values returns only shared apm targets when neither personal nor work" {
  local data
  data=$(printf '{"ctx":{"personal":false,"work":false},"valuesByGroup":%s}' "$APM_VALUES_BY_GROUP")

  run render_chezmoi_template "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '["graphify"]'
}

@test "active-groups returns shared, personal, and work when both are true" {
  run render_chezmoi_template "$ACTIVE_GROUPS_TMPL" "$BOTH_DATA"

  assert_success
  assert_output '["shared","personal","work"]'
}

@test "active-group-values silently skips groups absent from valuesByGroup" {
  local data
  data=$(printf '{"ctx":{"personal":true,"work":false},"valuesByGroup":%s}' "$APM_VALUES_SPARSE")

  run render_chezmoi_template "$ACTIVE_GROUP_VALUES_TMPL" "$data"

  assert_success
  assert_output '["graphify"]'
}
