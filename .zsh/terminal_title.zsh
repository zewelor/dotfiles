# Terminal title helpers shared across different terminal emulators
# Requirements:
# - Automatically set the title on shell startup, after every prompt refresh, and on each directory change
# - Use the current directory only (no user@host) in the rendered title

autoload -Uz add-zsh-hook

# Minimal: always send OSC 2; limit to 40 chars
typeset -g ZSH_TITLE_MAX=${ZSH_TITLE_MAX-40}

# Use a user@hostname prefix when the session is remote.
_title_terminal_session_prefix() {
  [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ]] || return 0
  local host
  host=${HOSTNAME:-}
  if [[ -z "$host" ]]; then
    if host_tmp=$(hostname -s 2>/dev/null); then
      host=$host_tmp
    fi
  fi
  [[ -n "$host" ]] || return 0
  printf '%s@%s: ' "${LOGNAME:-${USER}}" "$host"
}

_title_terminal() {
  emulate -L zsh
  [[ -t 1 ]] || return 0
  local input="$1"
  # Expand prompt escapes (e.g. %~)
  local expanded
  expanded=$(print -P -- "$input")
  local prefix
  prefix=$(_title_terminal_session_prefix)
  expanded="${prefix}${expanded}"
  # Truncate to max length with ascii ellipsis
  local max=$ZSH_TITLE_MAX
  if (( max > 0 && ${#expanded} > max )); then
    local cut=$(( max > 3 ? max-3 : max ))
    expanded="${expanded[1,$cut]}..."
  fi
  [[ $EUID -eq 0 ]] && expanded="# ${expanded}"
  # Emit OSC 2 only
  printf '\033]2;%s\007' "$expanded"
}

_title_terminal_pwd() {
  _title_terminal "%~"
}

_title_terminal_cmd() {
  emulate -L zsh
  local cmd="${1//\%/%%}"
  _title_terminal "${cmd}"
}

# Set the title to show the running command only for selected TUI/interactive tools.
typeset -ga ZSH_TITLE_CMD_WHITELIST=(
  vim nvim vi btop htop man mc fzf lazygit iotop
)

_title_preexec() {
  emulate -L zsh
  local line="$1"
  [[ -z "$line" ]] && return 0

  local -a words=("${(z)line}")
  [[ ${#words[@]} -eq 0 ]] && return 0
  local cmd="${words[1]}"

  # Check whitelist (case-insensitive match)
  local c
  for c in "${ZSH_TITLE_CMD_WHITELIST[@]}"; do
    if [[ "${cmd:l}" == "${c:l}" ]]; then
      _title_terminal_cmd "$line"
      return 0
    fi
  done
}

add-zsh-hook precmd _title_terminal_pwd
add-zsh-hook chpwd  _title_terminal_pwd
add-zsh-hook preexec _title_preexec
_title_terminal_pwd
