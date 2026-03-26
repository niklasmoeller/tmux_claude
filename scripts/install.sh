#!/usr/bin/env bash
# install.sh — idempotent Claude Code settings.json patcher for tmux-claude
# Called by tmux-claude.tmux on every tmux start; safe to run multiple times.
#
# Usage: install.sh <plugin_root_dir>
#
# Requires: jq

PLUGIN_DIR="${1:?usage: install.sh <plugin_root_dir>}"
SETTINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude/settings.json"
UPDATE_SCRIPT="$PLUGIN_DIR/scripts/update-state.sh"
SESSION_END_CMD="rm -f \"$PLUGIN_DIR/state/pane_\${TMUX_PANE#%}.json\""

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "tmux-claude: jq not found — skipping Claude Code settings.json setup" >&2
  exit 0
fi

# Create settings.json if absent
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

current=$(cat "$SETTINGS_FILE")

# ── statusLine ──────────────────────────────────────────────────────────────

existing_cmd=$(echo "$current" | jq -r '.statusLine.command // empty')

if echo "$existing_cmd" | grep -qF "update-state.sh"; then
  # Already pointing at our hook (possibly from a previous install or different path).
  # Skip statusLine setup but still check the SessionEnd hook below.
  :
elif [ -z "$existing_cmd" ]; then
  # No existing statusLine — set directly.
  current=$(echo "$current" | jq \
    --arg cmd "bash $UPDATE_SCRIPT" \
    '.statusLine = {"type": "command", "command": $cmd}')
else
  # Existing statusLine from another tool — write a wrapper that chains both.
  WRAPPER="$PLUGIN_DIR/scripts/statusline-wrapper.sh"
  cat > "$WRAPPER" << WRAPPER_EOF
#!/usr/bin/env bash
# statusline-wrapper.sh — chains existing statusLine with tmux-claude state writing.
# The existing command's output is passed through for display in Claude Code.
input=\$(cat)
existing_output=\$(printf '%s' "\$input" | $existing_cmd 2>/dev/null)
printf '%s' "\$input" | bash $UPDATE_SCRIPT
printf '%s' "\$existing_output"
WRAPPER_EOF
  chmod +x "$WRAPPER"
  current=$(echo "$current" | jq \
    --arg cmd "bash $WRAPPER" \
    '.statusLine = {"type": "command", "command": $cmd}')
fi

# ── SessionEnd cleanup hook ─────────────────────────────────────────────────

# Check if the cleanup command is already present anywhere in hooks.SessionEnd
already_present=$(echo "$current" | jq \
  --arg cmd "$SESSION_END_CMD" \
  '[.hooks.SessionEnd[]?.hooks[]?.command] | index($cmd) != null')

if [ "$already_present" != "true" ]; then
  current=$(echo "$current" | jq \
    --arg cmd "$SESSION_END_CMD" \
    '.hooks.SessionEnd //= [] |
     .hooks.SessionEnd += [{"hooks": [{"type": "command", "command": $cmd}]}]')
fi

# ── Write result ─────────────────────────────────────────────────────────────

echo "$current" > "$SETTINGS_FILE"
