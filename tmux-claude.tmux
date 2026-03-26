#!/usr/bin/env bash
# tmux-claude.tmux — TPM entry point
# Registers format variables and patches Claude Code settings.json (idempotent).

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Format variables — add these to your tmux.conf to opt in
#
#   Pane border (shows model + context % only in Claude Code panes):
#     set -g pane-border-status bottom
#     set -g pane-border-format "#{E:@claude_session}"
#
#   Status bar (shows 5h/7d token usage):
#     set -ag status-right " #{E:@claude_tokens}"
#     set -g status-interval 15
# ---------------------------------------------------------------------------
tmux set-option -gq "@claude_session" "#($PLUGIN_DIR/scripts/claude-session.sh #{pane_id})"
tmux set-option -gq "@claude_tokens" "#($PLUGIN_DIR/scripts/claude-tokens.sh)"

# Default format strings — skip if the user has already set them in tmux.conf
tmux show-option -gq @claude_session_format &>/dev/null || \
  tmux set-option -gq @claude_session_format \
    "{{context_window.used_percentage}}% @ {{model.display_name}}"
tmux show-option -gq @claude_tokens_format &>/dev/null || \
  tmux set-option -gq @claude_tokens_format \
    "{{rate_limits.five_hour.used_percentage}}% ↻ {{time:rate_limits.five_hour.resets_at:%H:%M}} | {{rate_limits.seven_day.used_percentage}}% ↻ {{time:rate_limits.seven_day.resets_at:%a %H:%M}}"

tmux source "${PLUGIN_DIR}/status/claude_tokens.conf"

# ---------------------------------------------------------------------------
# One-time Claude Code settings.json setup (idempotent, silent on success)
# ---------------------------------------------------------------------------
bash "$PLUGIN_DIR/scripts/install.sh" "$PLUGIN_DIR"
