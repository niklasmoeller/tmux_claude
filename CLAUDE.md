# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this plugin is

A tmux plugin (TPM-compatible) that displays Claude Code session state — active model, context window %, and token usage — in pane borders and the status bar. It bridges Claude Code's `statusLine` hook to tmux's polling-based display system via `state/` files in the plugin directory.

## Plugin structure

- `tmux-claude.tmux` — TPM entry point; sets `@claude_session`/`@claude_tokens` format variables, auto-configures Catppuccin if detected, calls `install.sh`
- `scripts/install.sh` — idempotent patcher for Claude Code's `settings.json`; adds the `statusLine` hook and `SessionEnd` cleanup; writes a wrapper script if another `statusLine` is already configured
- `scripts/update-state.sh` — Claude Code `statusLine` hook; writes full JSON payload to `state/` files; produces no stdout
- `scripts/lib.sh` — shared `render_template` helper; supports `{{field.path}}` and `{{time:field.path:strftime_fmt}}` syntax
- `scripts/claude-session.sh <pane_id>` — pane border display; renders `@claude_session_format` against per-pane state; outputs empty string for non-Claude panes
- `scripts/claude-tokens.sh` — status bar display; renders `@claude_tokens_format` against global state
- `scripts/catppuccin-claude-tokens.conf` — tmux module template for Catppuccin; `SCRIPTS_DIR` and `CATPPUCCIN_UTILS` are literal placeholders substituted by `tmux-claude.tmux` at runtime

## statusLine JSON payload (stdin to `update-state.sh`)

Claude Code v2.1.81+ passes this structure:

```json
{
  "session_id": "38049b20-...",
  "transcript_path": "/Users/user/.config/claude/projects/.../session.jsonl",
  "cwd": "/path/to/project",
  "session_name": "my-session",
  "model": {
    "id": "claude-sonnet-4-6",
    "display_name": "Sonnet 4.6"
  },
  "workspace": {
    "current_dir": "/path/to/project",
    "project_dir": "/path/to/project",
    "added_dirs": []
  },
  "version": "2.1.81",
  "output_style": { "name": "default" },
  "cost": {
    "total_cost_usd": 1.73,
    "total_duration_ms": 1752492,
    "total_api_duration_ms": 459658,
    "total_lines_added": 6,
    "total_lines_removed": 7
  },
  "context_window": {
    "total_input_tokens": 46,
    "total_output_tokens": 24032,
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 1,
      "output_tokens": 1,
      "cache_creation_input_tokens": 463,
      "cache_read_input_tokens": 94174
    },
    "used_percentage": 47,
    "remaining_percentage": 53
  },
  "exceeds_200k_tokens": false,
  "rate_limits": {
    "five_hour": {
      "used_percentage": 91,
      "resets_at": 1774382400
    },
    "seven_day": {
      "used_percentage": 18,
      "resets_at": 1774864800
    }
  }
}
```

The full JSON payload is stored verbatim in `state/` files — any field is referenceable in format strings without code changes.

## How the data flow works

1. Claude Code calls `update-state.sh` via `settings.json` → `statusLine.command` on every update
2. `update-state.sh` writes the full JSON payload to:
   - `state/pane_<id>.json` — full payload for the current `$TMUX_PANE`
   - `state/global.json` — latest payload (for the status bar, which isn't pane-specific)
3. tmux evaluates `#{E:@claude_session}` and `#{E:@claude_tokens}` on each status refresh; display scripts read the state files and render the user-configurable format string
4. Format strings use `{{field.path}}` for raw jq paths and `{{time:field.path:%H:%M}}` for epoch→local-time formatting

The pane ID strips the `%` prefix (e.g. `TMUX_PANE=%3` → `state/pane_3.json`) because `%` is special in tmux format strings.

## Format variables (user opt-in)

`tmux-claude.tmux` registers two display variables and two format options on every startup:

- `@claude_session` → `#(<plugin_dir>/scripts/claude-session.sh #{pane_id})`
- `@claude_tokens` → `#(<plugin_dir>/scripts/claude-tokens.sh)`
- `@claude_session_format` — template for pane border (default: `{{context_window.used_percentage}}% @ {{model.display_name}}`)
- `@claude_tokens_format` — template for status bar (default: `{{rate_limits.five_hour.used_percentage}}% ↻ {{time:rate_limits.five_hour.resets_at:%H:%M}} | {{rate_limits.seven_day.used_percentage}}% ↻ {{time:rate_limits.seven_day.resets_at:%a %H:%M}}`)

Users reference the display variables via `#{E:@claude_session}` and `#{E:@claude_tokens}` in their own `tmux.conf`, and override format options before the plugin loads. The plugin never auto-appends to `status-right` or `pane-border-format`.

## install.sh behaviour

- Idempotent: if `update-state.sh` path is already in `settings.json`'s `statusLine.command`, skips re-installation
- If an existing `statusLine` command is found (from another tool), writes `scripts/statusline-wrapper.sh` that pipes stdin to both commands and forwards the existing command's stdout to Claude Code's display
- Adds a `SessionEnd` hook entry only if not already present (checked by scanning `hooks.SessionEnd[*].hooks[*].command`)
- Requires `jq`; exits with a warning if not found

## Key constraints

- `update-state.sh` must produce **no stdout** — Claude Code displays whatever the `statusLine` command prints
- `catppuccin-claude-tokens.conf` is a template, not a directly sourceable file — `tmux-claude.tmux` generates a resolved copy at `/tmp/tmux-claude-catppuccin.conf` and sources that
- `claude-session.sh` exits silently for panes without a state file — keeps non-Claude pane borders clean
- Format option defaults are only set if not already present in tmux — user-set values in `tmux.conf` are preserved
