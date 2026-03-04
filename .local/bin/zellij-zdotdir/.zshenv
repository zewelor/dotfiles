# Bootstrap for zsh started by zsh-zellij-bootstrap.
# Restore default dotfiles and source project init if requested.

export ZDOTDIR="$HOME"

if [[ -n "${ZELLIJ_PROJECT_INIT:-}" && -f "${ZELLIJ_PROJECT_INIT}" ]]; then
  source "${ZELLIJ_PROJECT_INIT}"
fi

unset ZELLIJ_PROJECT_INIT
