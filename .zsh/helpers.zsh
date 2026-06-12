# Shared helper functions for dotfiles
# Sourced by both install script and .zshrc

# Check if a command exists
has() { command -v "${1:-}" >/dev/null 2>&1; }

# Return success when a symlink already points to the expected target.
symlink_points_to() {
  local link_path="${1:-}"
  local expected_target="${2:-}"
  local current_target=""

  [[ -L "$link_path" ]] || return 1
  current_target=$(readlink "$link_path" 2>/dev/null) || return 1
  [[ "$current_target" == "$expected_target" ]]
}

# Recreate a symlink only when the current target does not match.
ensure_symlink_target() {
  local target_path="${1:-}"
  local link_path="${2:-}"

  [[ -n "$target_path" && -n "$link_path" ]] || return 1
  mkdir -p "${link_path:h}"

  if symlink_points_to "$link_path" "$target_path"; then
    return 0
  fi

  if [[ -e "$link_path" || -L "$link_path" ]]; then
    rm -f "$link_path"
  fi

  ln -s "$target_path" "$link_path"
}

# Resolve browser command from XDG settings or fallback list
# Returns the browser command or empty string if not found
resolve_browser_cmd() {
  local detected="${BROWSER:-}"

  if [[ -z "$detected" ]]; then
    # Try XDG default browser
    local default_desktop
    default_desktop=$(xdg-settings get default-web-browser 2>/dev/null || true)

    if [[ -n "$default_desktop" ]]; then
      local desktop_path=""
      for dir in "/usr/share/applications" "$HOME/.local/share/applications"; do
        if [[ -f "$dir/$default_desktop" ]]; then
          desktop_path="$dir/$default_desktop"
          break
        fi
      done

      if [[ -n "$desktop_path" ]]; then
        local exec_line
        exec_line=$(grep -m1 '^Exec=' "$desktop_path" || true)
        if [[ -n "$exec_line" ]]; then
          # Strip Exec= prefix and remove placeholders like %u, %U, %f, %F
          detected=$(print -r -- "${exec_line#Exec=}" | sed -E 's/ ?%[a-zA-Z]//g')
        fi
      fi
    fi

    # Fallback to known browser commands
    if [[ -z "$detected" ]]; then
      local browser_candidates=(
        "brave-origin-stable"
        "brave-origin"
        "brave-browser-stable"
        "brave-browser"
        "google-chrome-stable"
        "google-chrome"
        "chromium"
        "chromium-browser"
        "brave"
        "firefox"
      )
      for candidate in "${browser_candidates[@]}"; do
        if has "$candidate"; then
          detected="$candidate"
          break
        fi
      done
    fi

    detected="${detected:-xdg-open}"
  fi

  # Validate that command exists (check first word only to allow flags/paths)
  local first_word="${detected%% *}"
  if has "$first_word"; then
    echo "$detected"
  else
    echo ""
  fi
}

# GitHub Releases platform suffix for zinit bpick (Linux only)
_ghr_linux() {
  local arch
  case "$(uname -m)" in
    x86_64)        arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)             arch="x64" ;;
  esac
  print -r -- "linux-${arch}"
}
