#!/bin/sh
# Claude Code Status Line
# Single `jq` invocation, POSIX `sh`, two-line output.
# Authoritative JSON paths per https://code.claude.com/docs/en/statusline
#
# Line 1 (status):   model | effort | context bar | cost | 5h rate limit
# Line 2 (location): dir | worktree | branch | agent

input=$(cat)

# Single-pass JSON parse. `@sh` emits shell-safe single-quoted assignments
# so `eval` is injection-safe even on adversarial input.
eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // "?")",
  @sh "remaining=\(.context_window.remaining_percentage // "")",
  @sh "used=\(.context_window.used_percentage // "")",
  @sh "total_cost=\(.cost.total_cost_usd // "")",
  @sh "current_dir=\(.workspace.current_dir // .cwd // "")",
  @sh "worktree=\(.worktree.name // .workspace.git_worktree // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "agent_name=\(.agent.name // "")",
  @sh "rl_5h_pct=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "rl_5h_reset=\(.rate_limits.five_hour.resets_at // "")"
')"

# Fallback to env var (e.g., `max`) when the active model doesn't expose .effort.level
[ -z "$effort" ] && [ -n "$CLAUDE_CODE_EFFORT_LEVEL" ] && effort="$CLAUDE_CODE_EFFORT_LEVEL"

# --- Colors (stored as literal escape sequences; interpreted by final printf '%b') ---
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[35m'
DIM='\033[38;5;245m'
RST='\033[0m'

# @description Build a 10-cell progress bar from a percentage.
# @arg $1 string Percentage value (0-100, decimals stripped).
make_bar() {
  pct=${1%.*}
  [ -z "$pct" ] && pct=0
  width=10
  filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  [ "$filled" -lt 0 ] && filled=0
  i=0
  bar=""
  while [ "$i" -lt "$filled" ]; do
    bar="${bar}█"
    i=$((i + 1))
  done
  while [ "$i" -lt "$width" ]; do
    bar="${bar}░"
    i=$((i + 1))
  done
  printf '%s' "$bar"
}

# @description Pick threshold color for a usage percentage.
# Green <70, yellow 70-89, red >=90.
# @arg $1 string Percentage value.
threshold_color() {
  pct=${1%.*}
  [ -z "$pct" ] && pct=0
  if [ "$pct" -ge 90 ]; then
    printf '%s' "$RED"
  elif [ "$pct" -ge 70 ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$GREEN"
  fi
}

# @description Format a unix timestamp as "2:30PM".
# Supports both BSD (macOS) `date -r` and GNU `date -d`.
# @arg $1 string Unix epoch seconds.
fmt_reset_time() {
  ts="$1"
  [ -z "$ts" ] && return
  date -r "$ts" "+%-I:%M%p" 2>/dev/null ||
    date -d "@$ts" "+%-I:%M%p" 2>/dev/null
}

# @description Format one rate-limit block.
# @arg $1 string Usage percentage.
# @arg $2 string Reset Unix timestamp.
# @arg $3 string Label (e.g., "5h", "7d").
format_rate_limit() {
  pct="$1"
  reset_ts="$2"
  label="$3"
  [ -z "$pct" ] && return
  pct_int=${pct%.*}
  color=$(threshold_color "$pct_int")
  bar=$(make_bar "$pct_int")
  reset_time=$(fmt_reset_time "$reset_ts")
  if [ -n "$reset_time" ]; then
    printf '%s%s %s %s%%%s %sresets %s%s' "$color" "$label" "$bar" "$pct_int" "$RST" "$DIM" "$reset_time" "$RST"
  else
    printf '%s%s %s %s%%%s' "$color" "$label" "$bar" "$pct_int" "$RST"
  fi
}

# @description Append a segment to a line string with a dim "|" separator.
# Skips empty segments. Output captured via $().
# @arg $1 string Existing line accumulator.
# @arg $2 string Segment to append.
sep=" ${DIM}|${RST} "
add_segment() {
  base="$1"
  seg="$2"
  [ -z "$seg" ] && {
    printf '%s' "$base"
    return
  }
  if [ -z "$base" ]; then
    printf '%s' "$seg"
  else
    printf '%s%s%s' "$base" "$sep" "$seg"
  fi
}

# --- Line 1: status (model | context | cost | rate limits) ---
line1=""

# Model
# shellcheck disable=SC2154  # assigned by the jq | eval block above
line1=$(add_segment "$line1" "🤖 $model")

# Effort (💪 emoji, suppressed when missing or "default")
[ -n "$effort" ] && [ "$effort" != "default" ] &&
  line1=$(add_segment "$line1" "💪 $effort")

# Context window — show used%, color-coded by threshold (no bar; the number is the signal)
if [ -n "$used" ]; then
  used_int=${used%.*}
  color=$(threshold_color "$used_int")
  line1=$(add_segment "$line1" "🧠 ${color}${used_int}%${RST}")
elif [ -n "$remaining" ]; then
  rem_int=${remaining%.*}
  used_int=$((100 - rem_int))
  color=$(threshold_color "$used_int")
  line1=$(add_segment "$line1" "🧠 ${color}${used_int}%${RST}")
fi

# Cost
if [ -n "$total_cost" ]; then
  cost_display=$(printf '%s' "$total_cost" | awk '{printf "%.2f", $1}')
  line1=$(add_segment "$line1" "💰 \$${cost_display}")
fi

# 5-hour rate limit
# shellcheck disable=SC2154  # assigned by the jq | eval block above
rl_5h=$(format_rate_limit "$rl_5h_pct" "$rl_5h_reset" "5h")
[ -n "$rl_5h" ] && line1=$(add_segment "$line1" "⏱️  $rl_5h")

# --- Line 2: location (dir | worktree | branch | extras) ---
line2=""

# Directory: repo root if inside a git repo, else cwd basename
if [ -n "$current_dir" ]; then
  repo_root=$(cd "$current_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$repo_root" ]; then
    dir_display=$(basename "$repo_root")
  else
    dir_display=$(basename "$current_dir")
  fi
  line2=$(add_segment "$line2" "📁 ${CYAN}${dir_display}${RST}")
fi

# Worktree (covers both --worktree sessions and `git worktree add` directories)
[ -n "$worktree" ] && line2=$(add_segment "$line2" "🌳 $worktree")

# Git branch + staged/modified counts (single subshell to avoid 4 cd's)
if [ -n "$current_dir" ]; then
  git_str=$(
    cd "$current_dir" 2>/dev/null || exit 0
    git rev-parse --git-dir >/dev/null 2>&1 || exit 0
    b=$(git branch --show-current 2>/dev/null)
    [ -z "$b" ] && b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    s=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    m=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    out="$b"
    [ "$s" -gt 0 ] && out="${out} ${GREEN}+${s}${RST}"
    [ "$m" -gt 0 ] && out="${out} ${YELLOW}~${m}${RST}"
    printf '%s' "$out"
  )
  [ -n "$git_str" ] && line2=$(add_segment "$line2" "🌿 $git_str")
fi

# Active subagent (only renders in --agent or agent-config sessions)
[ -n "$agent_name" ] && line2=$(add_segment "$line2" "${MAGENTA}⚡${agent_name}${RST}")

# --- Output (single final printf, %b interprets the literal escape sequences) ---
printf '%b\n%b' "$line1" "$line2"
