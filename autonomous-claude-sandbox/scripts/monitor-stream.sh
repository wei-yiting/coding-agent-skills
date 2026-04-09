#!/usr/bin/env bash
#
# monitor-stream.sh — tail a claude stream-json log and print progress events
#
# Designed to be SOURCED by run-sandbox.sh. Exposes one function: monitor_stream
#
# Progress modes:
#   1. If PROGRESS_PATTERN is non-empty: grep bash tool-use commands matching the regex
#      and print the match. Used by BDD (passes `# [SJ]-[^\\]*`) and SDD (passes task markers).
#   2. If PROGRESS_PATTERN is empty: print every tool-use name as it happens
#      (e.g. "▸ Bash", "▸ Edit", "▸ Read"). Useful default for generic consumers.
#
# All output is scrubbed for obvious credential patterns before display. The full
# stream log is preserved on disk for debugging; scrubbing only affects the terminal.

monitor_stream() {
  local docker_pid="${1:?monitor_stream: missing docker_pid}"
  local stream_log="${2:?monitor_stream: missing stream_log}"
  local progress_pattern="${3:-}"

  local last_progress=""
  local last_line_count=0

  while kill -0 "$docker_pid" 2>/dev/null; do
    sleep 10
    [[ -f "$stream_log" ]] || continue

    if [[ -n "$progress_pattern" ]]; then
      # Pattern mode: scan bash commands matching the regex
      local current
      current=$(grep -o "\"command\":\"$progress_pattern" "$stream_log" 2>/dev/null \
        | tail -1 | sed 's/"command":"//' || true)
      if [[ -n "$current" && "$current" != "$last_progress" ]]; then
        _print_progress "$current"
        last_progress="$current"
      fi
    else
      # Default mode: print new tool-use events since last tick
      local current_count
      current_count=$(wc -l < "$stream_log" 2>/dev/null || echo 0)
      if [[ "$current_count" -gt "$last_line_count" ]]; then
        local new_tools
        new_tools=$(tail -n "+$((last_line_count + 1))" "$stream_log" 2>/dev/null \
          | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' 2>/dev/null \
          | sort -u || true)
        if [[ -n "$new_tools" ]]; then
          while IFS= read -r tool; do
            [[ -n "$tool" ]] && _print_progress "$tool"
          done <<< "$new_tools"
        fi
        last_line_count="$current_count"
      fi
    fi
  done
}

_print_progress() {
  # Scrub credential-like substrings before display
  local line="$1"
  local scrubbed
  scrubbed=$(echo "$line" \
    | sed -E 's/(Bearer|token|credentials|sk-ant-[a-zA-Z0-9_-]+)[^ ]*/[REDACTED]/gi')
  echo "  ▸ $scrubbed"
}
