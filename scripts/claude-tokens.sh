#!/usr/bin/env bash
# claude-tokens.sh
# Outputs rendered format string for the tmux status bar.
# Reads state/global.json written by update-state.sh (via Claude Code statusLine hook).
# Outputs a waiting message when no session has run yet.
#
# Format is read from tmux option @claude_tokens_format.
# Any field from the statusLine JSON payload is referenceable as {{field.path}}.
# Timestamps can be formatted as {{time:field.path:%H:%M}}.
#
# Usage in tmux.conf (plain):
#   set -ag status-right " #{E:@claude_tokens}"
#
# Usage with Catppuccin: see status/claude_tokens.conf

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$PLUGIN_DIR/scripts/lib.sh"

DEFAULT_FORMAT='{{rate_limits.five_hour.used_percentage | round}}% ↻ {{time:rate_limits.five_hour.resets_at:%H:%M}} | {{rate_limits.seven_day.used_percentage | round}}% ↻ {{time:rate_limits.seven_day.resets_at:%a %H:%M}}'

state_file="$PLUGIN_DIR/state/global.json"

if [ ! -f "$state_file" ]; then
  printf ' Waiting for claude code session...'
  exit 0
fi

json=$(cat "$state_file")

fmt=$(tmux show-option -gvq @claude_tokens_format 2>/dev/null)
fmt="${fmt:-$DEFAULT_FORMAT}"

output=$(render_template "$fmt" "$json")
printf ' %s' "$output"
