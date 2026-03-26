#!/usr/bin/env bash
# update-state.sh
# Claude Code statusLine hook — writes per-pane and global state for tmux scripts.
# Produces no output; Claude Code's statusline area is intentionally left blank.
#
# Writes (full statusLine JSON payload):
#   <plugin>/state/pane_<id>.json  — per active pane
#   <plugin>/state/global.json     — latest session (global, for status bar)

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$PLUGIN_DIR/state"

input=$(cat)

tmux_pane="${TMUX_PANE:-}"
if [ -n "$tmux_pane" ]; then
  mkdir -p "$STATE_DIR"
  safe_pane="${tmux_pane#%}"
  printf '%s\n' "$input" > "$STATE_DIR/pane_${safe_pane}.json"

  # Remove state files for panes that no longer exist
  active=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr -d '%' | paste -sd '|')
  if [ -n "$active" ]; then
    for f in "$STATE_DIR"/pane_*.json; do
      [ -f "$f" ] || continue
      id="${f#${STATE_DIR}/pane_}"; id="${id%.json}"
      echo "$id" | grep -qE "^(${active})$" || rm -f "$f"
    done
  fi
fi

# Write global state (available even outside tmux)
mkdir -p "$STATE_DIR"
printf '%s\n' "$input" > "$STATE_DIR/global.json"
