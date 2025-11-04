# Terminal title helpers shared across different terminal emulators

__terminal_title_escape () {
  emulate -L zsh
  local title="$1"

  [[ -z "${title}" ]] && return 1
  [[ -t 1 ]] || return 1

  printf '\e]0;%s\a' "${title}"
}

if [[ -n "${KONSOLE_DBUS_SERVICE}" && -n "${KONSOLE_DBUS_SESSION}" ]] && (( $+commands[qdbus] )); then
  set-konsole-tab-title-type () {
    emulate -L zsh
    local _title="$1"
    local _type="${2:-0}"

    [[ -z "${_title}" ]] && return 1

    qdbus >/dev/null "${KONSOLE_DBUS_SERVICE}" "${KONSOLE_DBUS_SESSION}" setTabTitleFormat "${_type}" "${_title}"
  }

  set-konsole-tab-title () {
    emulate -L zsh
    local _title="$1"

    [[ -z "${_title}" ]] && return 1

    set-konsole-tab-title-type "${_title}" || return 1
    set-konsole-tab-title-type "${_title}" 1
  }

  set-terminal-title () {
    emulate -L zsh
    local title="$1"

    [[ -z "${title}" ]] && return 1

    set-konsole-tab-title "${title}" || __terminal_title_escape "${title}"
  }
else
  set-terminal-title () {
    emulate -L zsh
    __terminal_title_escape "$@"
  }
fi
