#!/usr/bin/env bash
# lib.sh — shared helpers for tmux-claude display scripts.

# draw_bar <value> <max> <width> [partial]
# Horizontal fill bar. Full=█, empty=░.
# With partial=1: sub-character precision at fill boundary using ▁▂▃▄▅▆▇.
draw_bar() {
  awk -v val="$1" -v max="$2" -v w="$3" -v partial="${4:-0}" 'BEGIN {
    total_eighths = val / max * w * 8
    for (i = 0; i < w; i++) {
      col = total_eighths - i * 8
      if (col >= 8) {
        printf "█"
      } else if (partial && col >= 1) {
        if      (col >= 7) printf "▇"
        else if (col >= 6) printf "▆"
        else if (col >= 5) printf "▅"
        else if (col >= 4) printf "▄"
        else if (col >= 3) printf "▃"
        else if (col >= 2) printf "▂"
        else               printf "▁"
      } else {
        printf "░"
      }
    }
  }'
}

# draw_vbar <value> <max> <width>
# Single vertical-fill character (▁–█) chosen by value, repeated <width> times.
draw_vbar() {
  awk -v val="$1" -v max="$2" -v w="$3" 'BEGIN {
    level = int(val / max * 8 + 0.5)
    if (level > 8) level = 8
    if (level < 0) level = 0
    chars[0] = " "; chars[1] = "▁"; chars[2] = "▂"; chars[3] = "▃"
    chars[4] = "▄"; chars[5] = "▅"; chars[6] = "▆"; chars[7] = "▇"; chars[8] = "█"
    for (i = 0; i < w; i++) printf "%s", chars[level]
  }'
}

# _resolve_bar_args <json> <vfield> <maxarg> <width>
# Sets barval, barmax, barw. Returns 1 if either value is missing/empty.
_resolve_bar_args() {
  local json="$1" vfield="$2" maxarg="$3"
  barw="$4"
  barval=$(printf '%s' "$json" | jq -r ".${vfield} // empty" 2>/dev/null)
  if [[ "$maxarg" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    barmax="$maxarg"
  else
    barmax=$(printf '%s' "$json" | jq -r ".${maxarg} // empty" 2>/dev/null)
  fi
  [ -n "$barval" ] && [ -n "$barmax" ]
}

# render_template <format_string> <json_string>
#
# Replaces placeholders in <format_string> using values from <json_string>:
#
#   {{field.path}}                  — any jq path or expression
#   {{field.path | jq_filter}}      — jq expression (leading . optional)
#   {{time:field.path:strftime}}    — epoch → local time
#   {{bar:field:max:width}}         — horizontal fill bar (█/░)
#   {{bar:field:max:width:partial}} — horizontal fill bar with sub-char precision
#   {{vbar:field:max:width}}        — single vertical-fill char repeated width times
#
# max may be a numeric literal or a jq field path.
# Missing/null fields render as empty string.
render_template() {
  local fmt="$1" json="$2" result prev field tfmt path value barval barmax barw
  result="$fmt"
  prev=""
  while [ "$result" != "$prev" ]; do
    prev="$result"
    if [[ "$result" =~ \{\{bar:([^:}]+):([^:}]+):([0-9]+):([^}]+)\}\} ]]; then
      local vfield="${BASH_REMATCH[1]}" orig_max="${BASH_REMATCH[2]}" barmode="${BASH_REMATCH[4]}"
      if _resolve_bar_args "$json" "$vfield" "$orig_max" "${BASH_REMATCH[3]}"; then
        value=$(draw_bar "$barval" "$barmax" "$barw" 1)
      else
        value=""
      fi
      result="${result//\{\{bar:${vfield}:${orig_max}:${barw}:${barmode}\}\}/$value}"
    elif [[ "$result" =~ \{\{bar:([^:}]+):([^:}]+):([0-9]+)\}\} ]]; then
      local vfield="${BASH_REMATCH[1]}" orig_max="${BASH_REMATCH[2]}"
      if _resolve_bar_args "$json" "$vfield" "$orig_max" "${BASH_REMATCH[3]}"; then
        value=$(draw_bar "$barval" "$barmax" "$barw")
      else
        value=""
      fi
      result="${result//\{\{bar:${vfield}:${orig_max}:${barw}\}\}/$value}"
    elif [[ "$result" =~ \{\{vbar:([^:}]+):([^:}]+):([0-9]+)\}\} ]]; then
      local vfield="${BASH_REMATCH[1]}" orig_max="${BASH_REMATCH[2]}"
      if _resolve_bar_args "$json" "$vfield" "$orig_max" "${BASH_REMATCH[3]}"; then
        value=$(draw_vbar "$barval" "$barmax" "$barw")
      else
        value=""
      fi
      result="${result//\{\{vbar:${vfield}:${orig_max}:${barw}\}\}/$value}"
    elif [[ "$result" =~ \{\{time:([^:}]+):([^}]+)\}\} ]]; then
      field="${BASH_REMATCH[1]}"
      tfmt="${BASH_REMATCH[2]}"
      local epoch
      epoch=$(printf '%s' "$json" | jq -r ".${field} // empty" 2>/dev/null)
      if [ -n "$epoch" ] && [ "$epoch" != "null" ]; then
        value=$(date -r "$epoch" "+${tfmt}" 2>/dev/null)
      else
        value=""
      fi
      result="${result//\{\{time:${field}:${tfmt}\}\}/$value}"
    elif [[ "$result" =~ \{\{([^}]+)\}\} ]]; then
      path="${BASH_REMATCH[1]}"
      local expr="$path"
      [[ "$expr" == "."* ]] || expr=".${expr}"
      value=$(printf '%s' "$json" | jq -r "(${expr}) // empty" 2>/dev/null)
      result="${result//\{\{${path}\}\}/$value}"
    fi
  done
  printf '%s' "$result"
}
