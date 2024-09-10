# export OPENAI_API_IP=127.0.0.1
# export OPENAI_API_PORT=8082
# export OPENAI_API_BASE="http://${OPENAI_API_IP}:${OPENAI_API_PORT}/v1"
#
# # Opencommit
# export OCO_OPENAI_BASE_PATH=${OPENAI_API_BASE}

# Misc
# https://github.com/TheR1D/shell_gpt
# Installed via pipx, because docker version doesn't integrate with shell auto execution ( it executes commands inside docker )
if has "sgpt"; then
  # If OPENAI_API_IP is set and equals 127.0.0.1
  if [ -n "$OPENAI_API_IP" ] && [ "$OPENAI_API_IP" = "127.0.0.1" ]; then
    export OPENAI_API_KEY="whatever"
    export OPENAI_API_HOST="http://${OPENAI_API_IP}:${OPENAI_API_PORT}"
  fi

  # alias sgpt4="sgpt --model gpt-4"

  # Shell-GPT integration ZSH v0.2
  _sgpt_zsh() {
  if [[ -n "$BUFFER" ]]; then
      _sgpt_prev_cmd=$BUFFER
      BUFFER+="⌛"
      zle -I && zle redisplay
      BUFFER=$(sgpt --shell <<< "$_sgpt_prev_cmd" --no-interaction)
      zle end-of-line
  fi
  }
  zle -N _sgpt_zsh
  bindkey ^l _sgpt_zsh

  ## git summarize ##
  # Leverage SGPT to produce intelligent and context-sensitive git commit messages.
  # By providing one argument, you can define the type of semantic commit (e.g. feat, fix, chore).
  # When supplying two arguments, the second parameter allows you to include more details for a more explicit prompt.
  gsum() {
    if ! git diff --quiet --cached; then
      git_changes="$(git --no-pager diff --staged)"
      query="Please generate git commit message for following git diff. Respond only with git message. Dont quote it in markdown"
      if [ $# -eq 2 ]; then
        query+="Declare commit message as $1. $2."
      elif [ $# -eq 1 ]; then
        query+="Declare commit message as $1."
      else
      fi

      commit_message="$(echo "$git_changes" | sgpt "$query")"
      printf "%s\r\n\r\nDo you want to accept this commit? [Y/n]" "$commit_message"
      read -r "response?"
      if [[ $response =~ ^[Nn]$ ]]; then
        echo "Commit cancelled."
      else
        git commit -m "$commit_message"
      fi
    else
      echo "No staged changes found. Do you want to stage changes? [y/N]"
      read -r "response?"
      if [[ $response =~ ^[Yy]$ ]]; then
        git add .
        gsum "$@"
      else
        echo "Commit cancelled."
      fi
    fi
  }

  gsumpoa() {
    git add . && gsum "$@" && git push -u origin
  }
elif has "pipx" ; then
  pipx install shell-gpt
  echo "Please restart shell to enable shell-gpt integration"
fi
