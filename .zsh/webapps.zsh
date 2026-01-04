# Resolve $BROWSER if not provided (uses resolve_browser_cmd from helpers.zsh)
if [[ -z "$BROWSER" ]]; then
  export BROWSER="$(resolve_browser_cmd)"
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
  echo "Tip: add to dotfiles sync via webapps/apps.tsv:"
  echo "  ${APP_NAME}|${clean_name}|${APP_URL}|${ICON_URL}|"
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
