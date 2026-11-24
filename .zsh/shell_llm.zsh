# Generate commit messages with OpenCode on desktop.
if ! is_desktop; then
  return
fi

gsum() {
  # Function to generate commit message using the gemini model
  generate_commit_message() {
    # Check if we have staged changes
    if ! git --no-pager diff --cached --quiet >/dev/null 2>&1; then
      : # Has staged changes
    else
      printf '!!!\nNo staged changes detected.\n!!!\n'
      return 1
    fi

    local max_file_size=524288  # 512KB in bytes
    local max_total_diff=102400 # 100KB total diff limit

    # Get list of staged files with their diff sizes
    local -a large_files
    local -a normal_files

    while IFS=$'\t' read -r added deleted filename; do
      # Skip empty lines
      [ -z "$filename" ] && continue

      # Calculate approximate diff size (added + deleted lines * avg 50 bytes per line)
      local diff_size=0
      if [[ "$added" = "-" || "$deleted" = "-" ]]; then
        # Binary or otherwise non-numeric numstat; treat as large.
        diff_size=$((max_file_size + 1))
      else
        diff_size=$(((added + deleted) * 50))
      fi

      if [ "$diff_size" -gt "$max_file_size" ]; then
        # File too large - add to summary list
        large_files+=("Large file modified: $filename (~${diff_size} bytes diff)")
      else
        normal_files+=("$filename")
      fi
    done < <(git --no-pager diff --cached --numstat)

    local prompt='Below is a diff of staged changes. Generate a concise git commit message.
Rules:
- First line: short summary max 50 characters
- Then blank line, then bullet points (max 72 chars per line)
- Focus on WHAT changed and WHY, not every detail
- Use present tense, imperative mood
- If large files are mentioned, just note them without details'

    # Use a temp file to avoid "argument list too long" errors
    local tmpfile=$(mktemp)

    # Always include a compact overview (helps when diffs are truncated/excluded)
    {
      printf 'Staged changes (git diff --cached --stat):\n'
      git --no-pager diff --cached --stat
      printf '\n\n'
    } >"$tmpfile"

    # Write large files summary (if any)
    if (( ${#large_files[@]} )); then
      printf 'Large files (diffs excluded):\n' >>"$tmpfile"
      printf '%s\n' "${large_files[@]}" >>"$tmpfile"
      printf '\n' >>"$tmpfile"
    fi

    # Add diff for normal-sized files only
    if (( ${#normal_files[@]} )); then
      git --no-pager diff --cached -- "${normal_files[@]}" >>"$tmpfile" 2>/dev/null
    fi

    # Get file size and limit it
    local filesize=$(wc -c <"$tmpfile")
    if [ "$filesize" -gt "$max_total_diff" ]; then
      head -c "$max_total_diff" "$tmpfile" >"${tmpfile}.limited"
      mv "${tmpfile}.limited" "$tmpfile"
    fi

    if ! has "opencode"; then
      echo "Error: 'opencode' command is not available in PATH. Run 'mise install' to install it." >&2
      rm -f "$tmpfile"
      return 1
    fi

    # Use a private server for one-shot generation and keep successful runs quiet.
    # Disable Herdr integration reports and isolate the process from foreground detection;
    # --wait preserves the OpenCode exit status.
    # Use 'command cat' to bypass any user aliases (like cat -> bat) for maximum speed and raw output.
    local error_file="${tmpfile}.stderr"
    local response
    response=$(command cat "$tmpfile" | HERDR_ENV=0 setsid --wait opencode run --standalone -m google/gemini-flash-lite-latest "$prompt" 2>"$error_file")
    local result=$?

    if [ "$result" -ne 0 ] && [ -s "$error_file" ]; then
      command cat "$error_file" >&2
    fi

    rm -f "$tmpfile" "$error_file"
    if [ "$result" -ne 0 ]; then
      printf '%s' "$response"
      return $result
    fi

    # Extract the first complete Markdown code block when the model wraps its message.
    printf '%s\n' "$response" | awk '
      { original = original $0 "\n" }
      in_block && /^[[:blank:]]*```[[:blank:]]*$/ { closed = 1; exit }
      in_block { message = message $0 "\n"; next }
      /^[[:blank:]]*```[^`]*$/ { in_block = 1 }
      END { printf "%s", closed ? message : original }
    '
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
  # Uses file-based commit to avoid "argument list too long" errors
  do_commit() {
    local message="$1"
    shift  # Remove message from args, rest are git flags
    local msg_file=$(mktemp)

    # Write message to file to avoid argument length limits
    printf '%s' "$message" >"$msg_file"

    if git commit -F "$msg_file" "$@"; then
      rm -f "$msg_file"
      return 0
    else
      rm -f "$msg_file"
      echo "Commit failed. Please check your changes and try again."
      return 1
    fi
  }

  # Main script
  force_accept="false"
  git_args=()
  while [[ "$1" == -* ]]; do
    if [[ "$1" == -[yY] ]]; then
      force_accept="true"
    else
      git_args+=("$1")
    fi
    shift
  done

  commit_message=$(generate_commit_message)
  local gen_status=$?

  if [ $gen_status -ne 0 ]; then
    echo "$commit_message"
    echo "\nCommit message generation failed."
    return 1
  fi

  # Check if commit message is empty
  if [ -z "$commit_message" ]; then
    echo "Generated commit message is empty. Aborting."
    return 1
  fi

  if [ "$force_accept" = "true" ]; then
    do_commit "$commit_message" "${git_args[@]}"
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
      do_commit "$commit_message" "${git_args[@]}"
      return $?
      ;;
    [rR])
      echo "Regenerating commit message using gemini..."
      commit_message=$(generate_commit_message)
      if [ $? -ne 0 ]; then
        echo "Message generation failed. Keeping previous message."
      fi
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
  gsum "$@" && git pull && git push -u origin
}

gsumpoa() {
  git add . && gsumpo "$@"
}
