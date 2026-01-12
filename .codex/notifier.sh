#!/bin/bash
# Codex notification hook - sends desktop notifications on events.

set -euo pipefail

input=""
if [ "${1:-}" != "" ]; then
  if [ -r "$1" ] && [ "${1#\{}" = "$1" ]; then
    # If the first arg is a readable file (and doesn't look like raw JSON), treat it as payload file.
    input=$(cat "$1")
  else
    # Otherwise treat the first arg as the raw JSON payload.
    input="$1"
  fi
else
  if [ -t 0 ]; then
    echo "Usage: $0 '<json-payload>'  (or pass JSON on stdin)" >&2
    exit 2
  fi
  input=$(cat)
fi

event_type=$(echo "$input" | jq -r '.type // "unknown"')
turn_id=$(echo "$input" | jq -r '."turn-id" // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

message=""
case "$event_type" in
  "agent-turn-complete") message="Response finished" ;;
  *) message="Event: $event_type" ;;
esac

if [ -n "$turn_id" ]; then
  message="$message (turn $turn_id)"
fi

# Append cwd (shortened to last dir) if present
if [ -n "$cwd" ]; then
  dir_name=$(basename "$cwd")
  message="[$dir_name] $message"
fi

notified=false
if command -v notify-send >/dev/null 2>&1; then
  if notify-send "Codex" "$message" -i dialog-information >/dev/null 2>&1; then
    notified=true
  fi
fi

if [ "$notified" != "true" ] && [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tmux display-message "Codex: $message" >/dev/null 2>&1 || true
fi

# Send terminal bell to highlight tmux tab
if [ "${CODEX_NOTIFIER_DEBUG:-0}" = "1" ]; then
  echo "$message" >&2
fi

if [ -t 1 ]; then
  # Order matters: redirect stderr first, then try /dev/tty (otherwise open errors leak).
  printf '\a' 2>/dev/null > /dev/tty || true
fi
