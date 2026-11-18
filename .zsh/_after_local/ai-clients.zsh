# Expose shortcuts and cached completions for clients available in the current shell.
# Keep the shell and session files in the workspace after the client exits.
_ai_create_tmp_workspace() {
  local workspace_root="${TMPDIR:-/tmp}"
  local workspace
  workspace=$(mktemp -d "${workspace_root:a}/ai-workspace.XXXXXXXXXX") || return 1
  if ! builtin cd -- "$workspace"; then
    command rmdir -- "$workspace"
    return 1
  fi
}

if has codex; then
  has cdxc || alias cdxc='codex'
  has cdxrl || alias cdxrl='codex resume --last'
  has codexrl || alias codexrl='codex resume --last'

  if ! has cdxtmp; then
    function cdxtmp {
      _ai_create_tmp_workspace || return 1
      codex "$@"
    }
  fi

  if ! has codexgo; then
    function codexgo {
      # Keep the ChatGPT Go subscription credentials and sessions separate.
      local codex_home="${CODEX_GO_HOME:-$HOME/.codex-go}"

      mkdir -p "$codex_home" || return 1
      CODEX_HOME="$codex_home" command codex "$@"
    }
  fi

  if [[ -s "$ZSH_CACHE_DIR/completions/_codex" ]]; then
    autoload -Uz _codex
    zpcompdef _codex codex codexgo
  fi
fi

if has opencode; then
  has oc || alias oc='opencode'
  has occ || alias occ='opencode -c'
  # Alias for running opencode with server port (for nvim integration)
  has ocp || alias ocp='opencode --port'

  if ! has octmp; then
    function octmp {
      _ai_create_tmp_workspace || return 1
      opencode "$PWD" "$@"
    }
  fi

  if [[ -s "$ZSH_CACHE_DIR/completions/_opencode" ]]; then
    autoload -Uz _opencode
    zpcompdef _opencode opencode oc
  fi
fi

if has agy; then
  has agyp || alias agyp='agy -p'
  has agyc || alias agyc='agy -c'
  has agyi || alias agyi='agy -i'
fi
