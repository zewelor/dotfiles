# https://github.com/simonw/llm
#
# Setup gemini API https://github.com/simonw/llm/issues/564#issuecomment-2443139073
#
#

if has "llm"; then
  gsum() {
    # Function to generate commit message using the gemini model
    generate_commit_message() {
      local model="gemini-1.5-flash-8b-latest"

      git diff --cached | llm -m "$model" <<EOF
Below is a diff of all staged changes, coming from:
\`\`\`
git diff --cached
\`\`\`
Please generate a concise, one-line commit message for these changes.
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

    # Main script
    force_accept="false"
    if [ "$1" = "-f" ]; then
      force_accept="true"
      shift
    fi

    commit_message=$(generate_commit_message)

    if [ "$force_accept" = "true" ]; then
      if git commit -m "$commit_message"; then
        echo "Changes committed with forced message!"
        return 0
      else
        echo "Commit failed. Please check your changes and try again."
        return 1
      fi
    fi

    while true; do
      echo "\nGenerated Commit Message:"
      echo "-------------------------"
      echo "$commit_message"
      echo "-------------------------\n"

      # read_input "Do you want to (a)ccept, (e)dit, (r)egenerate, or (c)ancel? "
      read_input "Do you want to (a)ccept, (r)egenerate, or (c)ancel? "
      choice=$REPLY

      case "$choice" in
        [aA])
          if git commit -m "$commit_message"; then
            echo "Changes committed successfully!"
            return 0
          else
            echo "Commit failed. Please check your changes and try again."
            return 1
          fi
          ;;
        # 'e|E' )
        #   read_input "Enter your commit message: "
        #   commit_message=$REPLY
        #   if [ -n "$commit_message" ] && git commit -m "$commit_message"; then
        #     echo "Changes committed successfully with your message!"
        #     return 0
        #   else
        #     echo "Commit failed. Please check your message and try again."
        #     return 1
        #   fi
        #   ;;
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

  gsumpoa() {
    git add . && gsum "$@" && git pull ; git push -u origin
  }
elif has "pipx" ; then
  pipx install llm
  echo "Please restart shell to enable llm integration"
fi
