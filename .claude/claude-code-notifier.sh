#!/bin/bash
# Claude Code notification hook - sends desktop notifications on events.
#
# Hook input structure docs:
#   https://code.claude.com/docs/en/hooks#hook-input
#   https://code.claude.com/docs/en/hooks#notification
#   https://code.claude.com/docs/en/hooks#stop

input=$(cat)
message=$(echo "$input" | jq -r '.message // "Claude Code Notification"')
hook_event=$(echo "$input" | jq -r '.hook_event_name // "Unknown"')
cwd=$(echo "$input" | jq -r '.cwd // empty')

if [ $? -ne 0 ] || [ "$message" = "null" ]; then
  message="Claude Code Notification"
fi

case "$hook_event" in
  "SessionStart") message="Session started" ;;
  "SessionEnd") message="Session completed" ;;
  "Stop") message="Response finished" ;;
  "Notification") ;;
  *) message="$hook_event: $message" ;;
esac

# Append cwd (shortened to last dir) if present
if [ -n "$cwd" ]; then
  dir_name=$(basename "$cwd")
  message="[$dir_name] $message"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$message" -i dialog-information
else
  echo "Claude Code: $message"
fi

# Send terminal bell to highlight tmux tab
printf '\a' > /dev/tty 2>/dev/null || true
