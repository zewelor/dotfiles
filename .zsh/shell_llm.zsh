# https://github.com/simonw/llm
#
# Setup gemini API https://github.com/simonw/llm/issues/564#issuecomment-2443139073
#
#

if has "llm"; then
  gsum() {
    # Function to generate commit message using the gemini model
    generate_commit_message() {
      local model="gemini-2.0-flash"
      local diff_content=$(git --no-pager diff --cached)

      if [ -z "$diff_content" ]; then
        echo "!!!\nNo staged changes detected.\n!!!"
        return 1
      fi

      echo "$diff_content" | llm -m "$model" <<EOF
Below is a diff of all staged changes, coming from:

```
git diff --cached
```

Please generate a concise, git commit message for these changes. In the first line, write a short summary of the changes, do it in single file. In the following lines, provide more detailed context if necessary. Write it directly, without any markdown quotes.
EOF
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
    if [ "$1" = "-y" ]; then
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
    gsum "$@" && git pull ; git push -u origin
  }

  gsumpoa() {
    git add . && gsumpo "$@"
  }
elif has "pipx" ; then
  pipx install llm
  echo "Please restart shell to enable llm integration"
fi
