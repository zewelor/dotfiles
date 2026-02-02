# https://github.com/simonw/llm
#
# Setup gemini API https://github.com/simonw/llm/issues/564#issuecomment-2443139073
#
#

if ! is_desktop; then
  return
fi

# Lazy load Codex completions to improve shell startup time
function _codex() {
  # Remove the function to prevent recursion on subsequent calls
  unfunction $0

  # Ensure the completion system is initialized
  if ! type compinit &>/dev/null; then
    autoload -Uz compinit
    compinit
  fi

  eval "$(codex completion zsh)"

  # Re-run the completion function now that real completion is loaded
  $0 "$@"
}

zpcompdef _codex codex

# Run LLM tool in temp dir and cleanup on exit
_llm_tmp() {
  local tool="$1" dir_flag="$2"
  shift 2
  local tmpdir="$(mktemp -d)" || return 1
  trap 'rm -rf "$tmpdir"' EXIT

  if [[ -n "$dir_flag" ]]; then
    "$tool" "$dir_flag" "$tmpdir" "$@"
  else
    "$tool" "$tmpdir" "$@"
  fi
}

cdxtmp() {
  _llm_tmp codex "-C" "$@"
}

octmp() {
  _llm_tmp opencode "" "$@"
}

gsum() {
  # Function to generate commit message using the gemini model
  generate_commit_message() {
    local diff_content=$(git --no-pager diff --cached)

    if [ -z "$diff_content" ]; then
      echo "!!!\nNo staged changes detected.\n!!!"
      return 1
    fi

    local prompt='Below is a diff of all staged changes, coming from `git diff --cached`. Please generate a concise, git commit message for these changes. In the first line, write a short summary of the changes, do it in single file. In the following lines, provide more detailed context if necessary. Write it directly, without any markdown quotes.'

    echo "$diff_content" | opencode run -m github-copilot/gpt-5-mini "$prompt" 2>/dev/null
  }

  # Function to read user input compatibly with both Bash and Zsh
  read_input() {
    if [ -n "$ZSH_VERSION" ]; then
      echo -n "$1"
      read -r REPLY
    else
      read -p "$1" -r REPLY
    fi
  }

  # Function to commit changes and display result
  do_commit() {
    local message="$1"
    if git commit -m "$message"; then
      return 0
    else
      echo "Commit failed. Please check your changes and try again."
      return 1
    fi
  }

  # Main script
  force_accept="false"
  if [[ "$1" = -[yY] ]]; then
    force_accept="true"
    shift
  fi

  commit_message=$(generate_commit_message)

  if [ $? -ne 0 ]; then
    echo $commit_message
    echo "\nCommit message generation failed."
    return 1
  fi

  if [ "$force_accept" = "true" ]; then
    do_commit "$commit_message"
    return $?
  fi

  while true; do
    echo "\nGenerated Commit Message:"
    echo "-------------------------"
    echo "$commit_message"
    echo "-------------------------\n"

    read_input "Do you want to (a)ccept, (r)egenerate, or (c)ancel? "
    choice=$REPLY

    case "$choice" in
    [aA])
      do_commit "$commit_message"
      return $?
      ;;
    [rR])
      echo "Regenerating commit message using gemini..."
      commit_message=$(generate_commit_message)
      ;;
    [cC])
      echo "Commit cancelled."
      return 1
      ;;
    *)
      echo "Invalid choice. Please try again."
      ;;
    esac
  done
}

gsumpo() {
  gsum "$@" && git pull
  git push -u origin
}

gsumpoa() {
  git add . && gsumpo "$@"
}
