
jj() {
  local JJ_AUTOPUSH="1"

  emulate -L zsh
  setopt err_return pipe_fail nounset

  local JROOT="${JROOT:-$HOME/personal/journaling}"
  local REPO="${REPO:-git@github.com:zewelor/journaling.git}"
  local arg="${1:-}"
  local d

  umask 077

  # Ensure repo exists (clone if missing or not a git repo)
  if [[ ! -d "$JROOT/.git" ]]; then
    if [[ -e "$JROOT" && ! -d "$JROOT" ]]; then
      print -u2 -- "Error: $JROOT exists and is not a directory."
      return 1
    fi
    if [[ ! -d "$JROOT" || -z "$(ls -A -- "$JROOT" 2>/dev/null)" ]]; then
      mkdir -p -- "${JROOT:h}"
      print -- "Cloning journaling repo into $JROOT ..."
      git clone -- "$REPO" "$JROOT" || { print -u2 -- "Clone failed"; return 1 }
    else
      print -u2 -- "Warning: $JROOT exists but is not a git repo (.git missing)."
      return 1
    fi
  fi

  # Subcommands
  if [[ "$arg" == "sync" ]]; then
    git -C "$JROOT" pull --rebase --autostash
    git -C "$JROOT" push
    return $?
  fi

  # Date parsing (Linux/GNU date). Yesterday shortcut.
  if [[ "$arg" == "y" || "$arg" == "yesterday" ]]; then
    d="$(date -d yesterday +%F)"
  elif [[ "$arg" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
    d="$arg"
  else
    d="$(date +%F)"
  fi

  local year="${d%%-*}"
  local rest="${d#*-}"
  local month="${rest%%-*}"
  local f="$JROOT/$year/$month/$d.md"

  # Create file with a tiny template if missing
  mkdir -p -- "${f:h}"
  if [[ ! -f "$f" ]]; then
    {
      print -- "# $d"
      print
      print -- "## Samopoczucie\n"
      print -- "## Wdziecznosc / sukcesy\n"
      print -- "## Refleksje\n"
    } >| "$f"
  fi

  # Open in editor (VISUAL > EDITOR > vi)
  local ed="${VISUAL:-${EDITOR:-vi}}"
  "$ed" "$f"

  # Commit only if content changed
  local rel="${f#$JROOT/}"
  if [[ -n "$(git -C "$JROOT" status --porcelain -- "$rel")" ]]; then
    git -C "$JROOT" add -- "$rel"
    git -C "$JROOT" commit -m "journal: $d"
    [[ "${JJ_AUTOPUSH:-0}" == "1" ]] && git -C "$JROOT" remote get-url origin &>/dev/null && git -C "$JROOT" push || true
  fi
}

