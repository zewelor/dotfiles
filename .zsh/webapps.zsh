# Resolve $BROWSER if not provided
if [[ -z "$BROWSER" ]]; then
  DEFAULT_BROWSER_DESKTOP=$(xdg-settings get default-web-browser 2>/dev/null)

  if [[ -n "$DEFAULT_BROWSER_DESKTOP" ]]; then
    # Extract the Exec line from the .desktop file
    if [[ -f "/usr/share/applications/$DEFAULT_BROWSER_DESKTOP" ]]; then
      BROWSER_EXEC=$(grep -m1 '^Exec=' "/usr/share/applications/$DEFAULT_BROWSER_DESKTOP")
    elif [[ -f "$HOME/.local/share/applications/$DEFAULT_BROWSER_DESKTOP" ]]; then
      BROWSER_EXEC=$(grep -m1 '^Exec=' "$HOME/.local/share/applications/$DEFAULT_BROWSER_DESKTOP")
    fi

    # Clean up the Exec command (strip placeholders like %u, %U)
    if [[ -n "$BROWSER_EXEC" ]]; then
      BROWSER=$(print -r -- "$BROWSER_EXEC" | sed -E 's/^Exec=//' | sed -E 's/ ?%[a-zA-Z]//g')
    fi
  fi

  # If we couldn't detect it from .desktop, try common fallbacks
  for candidate in brave chromium google-chrome firefox; do
    if command -v "$candidate" >/dev/null 2>&1 && [[ -z "$BROWSER" ]]; then
      BROWSER="$candidate"
    fi
  done

  # Final fallback
  export BROWSER="${BROWSER:-xdg-open}"
fi

# Create a desktop launcher for a web app
web2app() {
  emulate -L zsh
  set -o pipefail

  if [[ "$#" -ne 3 ]]; then
    print -r -- "Usage: web2app <AppName> <AppURL> <IconURL> (IconURL must be PNG -- try https://dashboardicons.com)"
    return 1
  fi

  local APP_NAME="$1"
  local APP_URL="$2"
  local ICON_URL="$3"
  local ICON_DIR="$HOME/.local/share/applications/icons"

  # Clean name for filename
  local clean_name=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

  local DESKTOP_FILE="$HOME/.local/share/applications/${clean_name}.desktop"
  local ICON_PATH="${ICON_DIR}/${clean_name}.png"

  mkdir -p -- "$ICON_DIR"

  if ! curl -fsSL -o "$ICON_PATH" "$ICON_URL"; then
    print -r -- "Error: Failed to download icon."
    return 1
  fi

  # Zsh-safe quoting with ${(q)var}
  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=${APP_NAME}
Comment=${APP_NAME}
Exec=${(q)BROWSER} --new-window --ozone-platform=wayland --app=${(q)APP_URL} --name=${(q)APP_NAME} --class=${(q)clean_name}
Terminal=false
Type=Application
Categories=Network;WebApp;
Icon=${ICON_PATH}
StartupWMClass=$clean_name
StartupNotify=true
EOF

  echo "Created web app: $APP_NAME"
  echo "Desktop file: $DESKTOP_FILE"
}

web2app-remove() {
  emulate -L zsh
  set -o pipefail

  if [[ "$#" -ne 1 ]]; then
    print -r -- "Usage: web2app-remove <AppName>"
    return 1
  fi

  local APP_NAME="$1"
  local ICON_DIR="$HOME/.local/share/applications/icons"
  local clean_name=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

  local DESKTOP_FILE="$HOME/.local/share/applications/${clean_name}.desktop"
  local ICON_PATH="${ICON_DIR}/${clean_name}.png"

  rm -f -- "$DESKTOP_FILE"
  rm -f -- "$ICON_PATH"
}
