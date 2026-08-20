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
last_msg=$(echo "$input" | jq -r '."last-assistant-message" // empty')

# Clean up / truncate message preview (up to 160 characters, single line)
clean_preview=""
if [ -n "$last_msg" ]; then
  clean_preview=$(echo "$last_msg" | tr '\n\r' '  ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//')
  if [ ${#clean_preview} -gt 160 ]; then
    clean_preview="$(echo "$clean_preview" | cut -c 1-157)..."
  fi
fi

title="Codex"
urgency="normal"
icon="dialog-information"

if [ -n "$cwd" ]; then
  dir_name=$(basename "$cwd")
  title="Codex [$dir_name]"
fi

case "$event_type" in
  "agent-turn-complete")
    if [ -n "$clean_preview" ]; then
      body="$clean_preview"
    else
      body="Zadanie ukończone (oczekuje na odpowiedź)"
    fi
    ;;
  "approval-requested")
    urgency="critical"
    icon="dialog-warning"
    body="⚠️ Wymagana akceptacja akcji"
    if [ -n "$clean_preview" ]; then
      body="$body: $clean_preview"
    fi
    ;;
  *)
    body="Zdarzenie: $event_type"
    if [ -n "$clean_preview" ]; then
      body="$body ($clean_preview)"
    fi
    ;;
esac

if [ -n "$turn_id" ] && [ "${CODEX_NOTIFIER_SHOW_TURN:-0}" = "1" ]; then
  title="$title (turn $turn_id)"
fi

notified=false
if command -v notify-send >/dev/null 2>&1; then
  if notify-send -a "Codex" "$title" "$body" -u "$urgency" -i "$icon" >/dev/null 2>&1; then
    notified=true
  fi
fi

if [ "$notified" != "true" ] && [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tmux display-message "$title: $body" >/dev/null 2>&1 || true
fi

# Send terminal bell
if [ -t 1 ]; then
  # Order matters: redirect stderr first, then try /dev/tty (otherwise open errors leak).
  printf '\a' 2>/dev/null > /dev/tty || true
fi

if [ "${CODEX_NOTIFIER_DEBUG:-0}" = "1" ]; then
  echo "[$title] $body" >&2
fi
