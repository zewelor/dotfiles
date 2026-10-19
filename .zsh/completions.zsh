# Zinit adds this cache directory to fpath and replays these registrations after compinit.
# Refresh the files with bin/update-shell-completions after tool installation/upgrades.
for completion_tool in sourcetap gog opencode workmux; do
  [[ -s "$ZSH_CACHE_DIR/completions/_$completion_tool" ]] || continue
  autoload -Uz "_$completion_tool"
  if [[ "$completion_tool" == opencode ]]; then
    zpcompdef _opencode opencode oc
  else
    zpcompdef "_$completion_tool" "$completion_tool"
  fi
done
unset completion_tool
