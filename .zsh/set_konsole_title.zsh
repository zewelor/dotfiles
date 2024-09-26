if [ -n "$KONSOLE_DBUS_SERVICE" ]; then
  set-konsole-tab-title-type ()
  {
      local _title=$1
      local _type=${2:-0}
      [[ -z "${_title}" ]]               && return 1
      [[ -z "${KONSOLE_DBUS_SERVICE}" ]] && return 1
      [[ -z "${KONSOLE_DBUS_SESSION}" ]] && return 1
      qdbus >/dev/null "${KONSOLE_DBUS_SERVICE}" "${KONSOLE_DBUS_SESSION}" setTabTitleFormat "${_type}" "${_title}"
  }

  set-konsole-tab-title ()
  {
      set-konsole-tab-title-type $1 && set-konsole-tab-title-type $1 1
  }
fi
