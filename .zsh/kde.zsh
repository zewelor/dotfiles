if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]]; then
  # Define KDE-specific aliases
  if [ -n "$DISPLAY" ]; then
    alias rekde="kquitapp5 plasmashell || killall plasmashell && kstart5 plasmashell"
  fi

  if [ -x "$(command -v mixxx)" ]; then
    function start-dj () {
      cpu_performance
      kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false
      qdbus org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver org.kde.screensaver.configure
      sudo nice -n -10 su -c mixxx omen
      kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock true
      qdbus org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver org.kde.screensaver.configure
    }
  fi

  # Function to toggle KDE screen lock with optional wait time
  toggle_screen_lock() {
      local script_path="$HOME/.zsh/kde/toggle_screen_lock.sh"
      echo "script_path: $script_path"
      local wait_time="${1:-3600}"

      if [[ -x "$script_path" ]]; then
          "$script_path" "$wait_time"
      else
          echo "Error: toggle_screen_lock.sh not found or not executable."
      fi
  }
fi
