# Skip the not really helping Ubuntu global compinit
skip_global_compinit=1

# Begin added by argcomplete
fpath=( /usr/lib/python3/dist-packages/argcomplete/bash_completion.d "${fpath[@]}" )
# End added by argcomplete

# Disable delta pager in non-interactive shells (e.g., when LLMs or scripts run git commands)
# to avoid rich formatting/paging that wastes context window tokens and complicates diff parsing.
if [[ ! -o interactive ]]; then
  export GIT_PAGER=cat
fi

