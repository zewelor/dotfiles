#!/usr/bin/env zsh

tmp_dir="${1:-}"
session_name="${2:-}"
shift 2

typeset -a sync_cmd
sync_cmd=("$@")

if [[ -z "$tmp_dir" || -z "$session_name" || ${#sync_cmd[@]} -eq 0 ]]; then
  printf 'usage: %s <tmp_dir> <session_name> <sync_cmd...>\n' "$0" >&2
  exit 1
fi

typeset sync_pid=""
typeset -i interrupt_count=0
typeset -i cleanup_done=0
typeset -i was_interrupted=0

cleanup() {
  (( cleanup_done )) && return 0
  cleanup_done=1

  trap - INT TERM HUP QUIT EXIT

  cd /tmp 2>/dev/null || cd / || true

  if [[ -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi

  tmux kill-session -t "$session_name" 2>/dev/null || true
}

stop_sync() {
  local signal_name="${1:-INT}"

  [[ -n "$sync_pid" ]] || return 0

  command kill "-${signal_name}" -- "-${sync_pid}" 2>/dev/null || \
    command kill "-${signal_name}" "$sync_pid" 2>/dev/null || true
}

TRAPINT() {
  was_interrupted=1

  if [[ -z "$sync_pid" ]] || ! kill -0 "$sync_pid" 2>/dev/null; then
    return 0
  fi

  (( interrupt_count += 1 ))

  if (( interrupt_count == 1 )); then
    printf '\nStopping sync gracefully...\n'
    stop_sync INT
  elif (( interrupt_count == 2 )); then
    printf '\nSync is still stopping; escalating to TERM...\n'
    stop_sync TERM
  else
    printf '\nForce killing sync...\n'
    stop_sync KILL
  fi

  return 0
}

TRAPTERM() {
  was_interrupted=1
  stop_sync TERM
  return 0
}

TRAPHUP() {
  was_interrupted=1
  stop_sync TERM
  return 0
}

TRAPQUIT() {
  was_interrupted=1
  stop_sync QUIT
  return 0
}

TRAPEXIT() {
  cleanup
}

if ! command -v setsid >/dev/null 2>&1; then
  printf 'podmount requires setsid for graceful shutdown\n' >&2
  exit 1
fi

setsid "${sync_cmd[@]}" &
sync_pid=$!

while true; do
  wait "$sync_pid"

  if ! kill -0 "$sync_pid" 2>/dev/null; then
    break
  fi
done

sync_pid=""

if (( was_interrupted )); then
  cleanup
  exit 0
fi

printf '\nSync stopped. Press any key to exit and cleanup %s...\n' "$tmp_dir"
read -k1 || true

cleanup
