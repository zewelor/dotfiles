#!/bin/bash
# Codex notification hook - notifies only when a user thread finishes a turn.

set -euo pipefail

debug() {
  if [ "${CODEX_NOTIFIER_DEBUG:-0}" = "1" ]; then
    printf '[Codex notifier] %s\n' "$1" >&2
  fi
}

if [ "${1:-}" != "" ]; then
  if [ -r "$1" ] && [ "${1#\{}" = "$1" ]; then
    input=$(<"$1")
  else
    input="$1"
  fi
elif [ ! -t 0 ]; then
  input=$(cat)
else
  printf "Usage: %s '<json-payload>' (or pass JSON on stdin)\n" "$0" >&2
  exit 2
fi

event_type=$(printf '%s' "$input" | jq -er '.type')
if [ "$event_type" != "agent-turn-complete" ]; then
  debug "Ignored event: $event_type"
  exit 0
fi

thread_id=$(printf '%s' "$input" | jq -er '."thread-id"')
turn_id=$(printf '%s' "$input" | jq -er '."turn-id"')
case "$thread_id$turn_id" in
  *[![:alnum:]_-]*)
    debug "Ignored invalid thread or turn id"
    exit 0
    ;;
esac

# The legacy notify payload does not identify subagents. Codex's local thread
# index does, so fail closed unless this completion belongs to a user thread.
codex_home="${CODEX_HOME:-$HOME/.codex}"
if ! command -v sqlite3 >/dev/null 2>&1; then
  debug "Ignored event: sqlite3 is not available"
  exit 0
fi

state_db=$(find "$codex_home" -maxdepth 1 -type f -name 'state_*.sqlite' -print | sort -V | tail -n 1)
if [ -z "$state_db" ]; then
  debug "Ignored event: Codex state database not found"
  exit 0
fi

thread_source=$(sqlite3 -batch -noheader "$state_db" "
  SELECT CASE
    WHEN thread_source IN ('user', 'subagent') THEN thread_source
    WHEN source IN ('cli', 'vscode', 'exec') THEN 'user'
    WHEN source LIKE '{\"subagent\"%' THEN 'subagent'
    ELSE 'unknown'
  END
  FROM threads
  WHERE id = '$thread_id'
  LIMIT 1;
")
if [ "$thread_source" != "user" ]; then
  debug "Ignored $thread_source thread: $thread_id"
  exit 0
fi

# Codex can replay or deliver the same completion more than once. An atomic
# per-login marker guarantees one notification for each thread/turn pair.
if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
  debug "Ignored event: XDG runtime directory not found"
  exit 0
fi

dedupe_dir="$XDG_RUNTIME_DIR/codex-notifier"
mkdir -p "$dedupe_dir"
chmod 700 "$dedupe_dir"
if ! mkdir "$dedupe_dir/$thread_id-$turn_id" 2>/dev/null; then
  debug "Ignored duplicate turn: $turn_id"
  exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
title="Codex"
if [ -n "$cwd" ]; then
  title="Codex [$(basename "$cwd")]"
fi
body="Zadanie ukończone"

if command -v notify-send >/dev/null 2>&1; then
  notify-send \
    -a "Codex" \
    -u "normal" \
    -i "dialog-information" \
    -h "boolean:suppress-sound:true" \
    "$title" "$body" >/dev/null 2>&1
elif [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tmux display-message "$title: $body" >/dev/null 2>&1
fi

debug "$title: $body"
