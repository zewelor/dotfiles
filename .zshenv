# Skip the not really helping Ubuntu global compinit
skip_global_compinit=1

# Begin added by argcomplete
fpath=( /usr/lib/python3/dist-packages/argcomplete/bash_completion.d "${fpath[@]}" )
# End added by argcomplete

export MISE_CONFIG_DIR="${HOME}/dotfiles/.config/mise"

# Keep mise available without installing precmd/chpwd activation hooks.
path=(
  "$HOME/.local/bin"
  "$HOME/.local/share/mise/shims"
  $path
)
typeset -U path
