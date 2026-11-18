# Zinit adds this cache directory to fpath and replays these registrations after compinit.
# Refresh the files with bin/update-shell-completions after tool installation/upgrades.
for completion_tool in sourcetap gog dockerfmt; do
  [[ -s "$ZSH_CACHE_DIR/completions/_$completion_tool" ]] || continue
  autoload -Uz "_$completion_tool"
  zpcompdef "_$completion_tool" "$completion_tool"
done
unset completion_tool
