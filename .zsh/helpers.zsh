# Shared helper functions for dotfiles
# Sourced by both install script and .zshrc

# Check if a command exists
has() { command -v "${1:-}" >/dev/null 2>&1; }

# Fetch a Vault JSON response without exposing the token in process arguments.
vault_http_get() (
  local url="${1:-}"
  local token="${2:-}"
  local temp_root="${TMPDIR:-/tmp}"
  local temp_dir=""
  local header_file=""
  local -i curl_status=0
  local -i cleanup_status=0

  cleanup_vault_http_temp() {
    local -i cleanup_status=0
    if [[ -n "$header_file" && -e "$header_file" ]] && ! command rm -f -- "$header_file"; then
      cleanup_status=1
    fi
    if [[ -n "$temp_dir" && -d "$temp_dir" ]] && ! command rmdir -- "$temp_dir"; then
      cleanup_status=1
    fi
    if (( cleanup_status != 0 )); then
      print -u2 -- "vault_http_get: failed to remove temporary credential files"
    fi
    return "$cleanup_status"
  }

  if [[ -z "$url" || -z "$token" ]]; then
    print -u2 -- "vault_http_get: URL and token are required"
    return 1
  fi

  temp_dir=$(mktemp -d "$temp_root/dotfiles-vault.XXXXXX") || return 1
  header_file="$temp_dir/header"
  trap cleanup_vault_http_temp EXIT
  trap 'trap - EXIT; cleanup_vault_http_temp; exit 130' HUP INT TERM
  if ! (umask 077 && print -r -- "X-Vault-Token: $token" > "$header_file"); then
    return 1
  fi

  curl --fail --silent --show-error --request GET --header "@$header_file" "$url" || curl_status=$?

  trap - EXIT
  cleanup_vault_http_temp || cleanup_status=$?
  trap - HUP INT TERM

  if (( curl_status != 0 )); then
    return "$curl_status"
  fi
  return "$cleanup_status"
)

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
