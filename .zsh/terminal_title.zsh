# Terminal title helpers shared across different terminal emulators
# Requirements:
# - Automatically set the title on shell startup, after every prompt refresh, and on each directory change
# - Use the current directory only (no user@host) in the rendered title

autoload -Uz add-zsh-hook

_title_terminal() {
  emulate -L zsh
  [[ -t 1 ]] || return 0
  # Send both OSC 0 (icon+title) and OSC 2 (title) for compatibility
  print -Pn -- "\e]0;$1\a"
  print -Pn -- "\e]2;$1\a"
}

_title_terminal_pwd() {
  _title_terminal "%~"
}

_title_terminal_cmd() {
  emulate -L zsh
  local cmd="${1//\%/%%}"
  _title_terminal "%~: ${cmd}"
}

# Set the title to show the running command only for selected TUI/interactive tools.
# The list below was built from your last ~6 months of usage.
typeset -ga ZSH_TITLE_CMD_WHITELIST=(
  vim nvim vi btop htop man mc fzf lazygit iotop
)

_title_preexec() {
  emulate -L zsh
  local line="$1"
  [[ -z "$line" ]] && return 0

  # Strip common prefixes that aren't the real command
  local raw="$line"
  for pfx in "sudo " "doas " "command " "nocorrect " "noglob "; do
    if [[ "$raw" == ${~pfx}* ]]; then
      raw="${raw#${~pfx}}"
    fi
  done

  # Extract first non-option token, skipping env assignments and sudo options
  local first
  first="${raw%% *}"
  while [[ -n "$first" && ( "$first" == *=* || "$first" == -* ) ]]; do
    raw="${raw#* }"
    first="${raw%% *}"
  done
  local cmd="$first"
  [[ -z "$cmd" ]] && return 0

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
