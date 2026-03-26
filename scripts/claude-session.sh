#!/usr/bin/env bash
# claude-session.sh <pane_id>
# Outputs rendered format string for the tmux pane border.
# Exits silently for panes without an active Claude session.
#
# Format is read from tmux option @claude_session_format.
# Any field from the statusLine JSON payload is referenceable as {{field.path}}.
# Timestamps can be formatted as {{time:field.path:%H:%M}}.
#
# Usage in tmux.conf:
#   set -g pane-border-status bottom
#   set -g pane-border-format "#{E:@claude_session}"

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$PLUGIN_DIR/scripts/lib.sh"

DEFAULT_FORMAT='{{context_window.used_percentage // 0 | round}}% {{bar:context_window.used_percentage // 0:100:20:partial}} | {{model.display_name}} | {{.session_name // .session_id}}'

current_pane="${1:-}"
[ -n "$current_pane" ] || exit 0

safe_pane="${current_pane#%}"
state_file="$PLUGIN_DIR/state/pane_${safe_pane}.json"
[ -f "$state_file" ] || exit 0

json=$(cat "$state_file")

fmt=$(tmux show-option -gvq @claude_session_format 2>/dev/null)
fmt="${fmt:-$DEFAULT_FORMAT}"

output=$(render_template "$fmt" "$json")
printf ' %s ' "$output"
