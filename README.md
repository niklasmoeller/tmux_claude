# tmux-claude

tmux plugin that shows [Claude Code](https://claude.ai/code) session info in your pane borders and status bar.

- **Pane border** — any field from the Claude Code session, only in panes running Claude Code
- **Status bar** — token usage, reset times, or any other session data

```
 ┌──────────────────────────────────────────────────────────────────────────────────────────────┐
 │  [0] my-project  [1] server                                   91% ↻ 14:00 │ 18% ↻ Thu 12:00  │
 ├──────────────────────────────────────────────────────┬───────────────────────────────────────┤
 │  $ claude                                            │  $ vim server.py                      │
 │                                                      │                                       │
 │  ✻ Working on your task…                             │                                       │
 │    Edited server.py                                  │                                       │
 │                                                      │                                       │
 ├─ 47% █████████▃░░░░░░░░░░ │ Sonnet 4.6 │ my-project ─┼───────────────────────────────────────┤
 └──────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [tmux](https://github.com/tmux/tmux) ≥ 3.0
- [`jq`](https://stedolan.github.io/jq/)
- [Claude Code](https://claude.ai/code)

## Install

### With TPM

Add to your `tmux.conf`:

```tmux
set -g @plugin 'niklasmoeller/tmux-claude'
```

Then press `prefix + I` to install.

### Manual

```sh
git clone https://github.com/niklasmoeller/tmux-claude ~/.tmux/plugins/tmux-claude
bash ~/.tmux/plugins/tmux-claude/tmux-claude.tmux
```

## Usage

The plugin does **not** modify your statusline automatically. Add the variables you want to your `tmux.conf`:

**Pane border** (only shown in panes with an active Claude Code session):

```tmux
set -g pane-border-status bottom
set -g pane-border-format "#{E:@claude_session}"
```

**Status bar** (token usage):

```tmux
set -ag status-right " #{E:@claude_tokens}"
set -g status-interval 15
```

### With Catppuccin

If the [Catppuccin tmux theme](https://github.com/catppuccin/tmux) is installed, `tmux-claude` auto-detects it and registers a `claude_tokens` module:

```tmux
set -ag status-right "#{E:@catppuccin_status_claude_tokens}"
```

## Customizing the format

Both display variables are driven by a format string stored in a tmux option. Set these in your `tmux.conf` **before** the plugin loads to override the defaults.

### Template syntax

| Syntax                            | Description                                                   |
| --------------------------------- | ------------------------------------------------------------- |
| `{{field.path}}`                  | Any field from the Claude Code statusLine JSON                |
| `{{field.path \| jq_expr}}`       | jq filter applied to the field                                |
| `{{.field_a - .field_b}}`         | Expression across multiple fields (requires leading `.`)      |
| `{{time:field.path:format}}`      | Epoch timestamp formatted as local time (`strftime` format)   |
| `{{bar:field:max:width}}`         | Horizontal fill bar — `█` filled, `░` empty                   |
| `{{bar:field:max:width:partial}}` | Same bar with sub-character precision at boundary (`▁▂▃▄▅▆▇`) |
| `{{vbar:field:max:width}}`        | Single vertical-fill char (`▁`–`█`) repeated `width` times    |

`max` may be a numeric literal (`100`) or another field path. Missing/null fields render as empty.

Missing or null fields render as an empty string.

### Pane border — `@claude_session_format`

Default:

```tmux
set -g @claude_session_format "{{context_window.used_percentage // 0 | round}}% {{bar:context_window.used_percentage // 0:100:20:partial}} | {{model.display_name}} | {{.session_name // .session_id}}"
```

Examples:

```tmux
# Add session name
set -g @claude_session_format "{{session_name}}  {{context_window.used_percentage | round}}% @ {{model.display_name}}"

# Show remaining context instead of used
set -g @claude_session_format "{{context_window.remaining_percentage | round}}% left · {{model.display_name}}"
```

### Status bar — `@claude_tokens_format`

Default:

```tmux
set -g @claude_tokens_format "{{rate_limits.five_hour.used_percentage | round}}% ↻ {{time:rate_limits.five_hour.resets_at:%H:%M}} | {{rate_limits.seven_day.used_percentage | round}}% ↻ {{time:rate_limits.seven_day.resets_at:%a %H:%M}}"
```

Examples:

```tmux
# Compact — percentages only
set -g @claude_tokens_format "{{rate_limits.five_hour.used_percentage | round}}% 5h | {{rate_limits.seven_day.used_percentage | round}}% 7d"

# Show session cost
set -g @claude_tokens_format "${{cost.total_cost_usd}} · {{rate_limits.five_hour.used_percentage | round}}% 5h"
```

### Available fields

The full Claude Code statusLine JSON payload is available. Key fields:

| Field                                   | Example value         |
| --------------------------------------- | --------------------- |
| `session_name`                          | `"my-project"`        |
| `model.display_name`                    | `"Sonnet 4.6"`        |
| `model.id`                              | `"claude-sonnet-4-6"` |
| `context_window.used_percentage`        | `47`                  |
| `context_window.remaining_percentage`   | `53`                  |
| `context_window.context_window_size`    | `200000`              |
| `rate_limits.five_hour.used_percentage` | `91`                  |
| `rate_limits.five_hour.resets_at`       | `1774382400` (epoch)  |
| `rate_limits.seven_day.used_percentage` | `18`                  |
| `rate_limits.seven_day.resets_at`       | `1774864800` (epoch)  |
| `cost.total_cost_usd`                   | `1.73`                |
| `version`                               | `"2.1.81"`            |

## How it works

Claude Code calls `update-state.sh` on every statusline update via a `statusLine` hook in `settings.json` (written automatically on first tmux start). The full JSON payload is stored verbatim:

- `<plugin>/state/pane_<id>.json` — full payload for the current pane
- `<plugin>/state/global.json` — latest payload (used by the status bar)

tmux polls `claude-session.sh` and `claude-tokens.sh` on each status refresh. Each script reads the state file, resolves `{{...}}` placeholders against the JSON using `jq`, and outputs the formatted string.

A `SessionEnd` hook removes the pane state file when a Claude Code session ends.
