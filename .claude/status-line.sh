#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
current_usage=$(echo "$input" | jq '.context_window.current_usage')

# Colors for light terminal background
DIR='\033[38;5;24m'          # dark blue (directory)
MODEL='\033[38;5;24m'        # dark blue (model name)
VCS='\033[38;5;28m'          # dark green (git branch)
MOD='\033[38;5;136m'         # dark gold (git added/modified)
ERR='\033[38;5;160m'         # dark red (git deleted)
SEP='\033[38;5;242m'         # dark grey (separators)
BAR_FILLED='\033[38;5;242m'  # dark grey (progress bar filled)
BAR_EMPTY='\033[38;5;252m'   # light grey (progress bar empty)
NC='\033[0m'

# Git branch icon (Nerd Fonts)
GIT_ICON=$'\ue725'

# Fish-style path shortening (like Starship fish_style_pwd_dir_length=1)
fish_style_path() {
    local path="$1"
    # Replace /home/omen with ~
    path="${path/#$HOME/\~}"

    # Split path into components
    IFS='/' read -ra parts <<< "$path"
    local result=""

    # Process all parts except the last one
    for ((i=0; i<${#parts[@]}-1; i++)); do
        local part="${parts[i]}"
        if [ -n "$part" ]; then
            # Shorten to first character
            result+="${part:0:1}/"
        elif [ $i -eq 0 ]; then
            # Keep empty first part for absolute paths
            result+="/"
        fi
    done

    # Add last part unshortened
    local last_idx=$((${#parts[@]} - 1))
    result+="${parts[$last_idx]}"
    echo "$result"
}

# Calculate context percentage
if [ "$current_usage" != "null" ]; then
    current_tokens=$(echo "$current_usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    context_percent=$((current_tokens * 100 / context_size))
else
    context_percent=0
fi

# Build context progress bar (15 chars wide)
bar_width=15
filled=$((context_percent * bar_width / 100))
empty=$((bar_width - filled))

bar=""
for ((i = 0; i < filled; i++)); do bar+="${BAR_FILLED}█"; done
for ((i = 0; i < empty; i++)); do bar+="${BAR_EMPTY}█"; done
bar+="${NC}"

# Cost extraction
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
[ "$session_cost" != "empty" ] && session_cost=$(printf "%.4f" "$session_cost") || session_cost=""

# Directory info
dir_name=$(fish_style_path "$current_dir")
cd "$current_dir" 2>/dev/null || cd /

# Git information
git_info=""

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    status_output=$(git status --porcelain 2>/dev/null)

    if [ -n "$status_output" ]; then
        # Count by status type (like Starship)
        staged=$(echo "$status_output" | grep '^[MADRC]' 2>/dev/null | wc -l | tr -d ' ')
        modified=$(echo "$status_output" | grep '^.M' 2>/dev/null | wc -l | tr -d ' ')
        deleted=$(echo "$status_output" | grep '^.D' 2>/dev/null | wc -l | tr -d ' ')
        untracked=$(echo "$status_output" | grep '^??' 2>/dev/null | wc -l | tr -d ' ')

        # Build status string like Starship: [+2 !1 ?3 -1]
        git_status=""
        [ "$staged" -gt 0 ] && git_status="${git_status}${MOD}+${staged}${NC} "
        [ "$modified" -gt 0 ] && git_status="${git_status}${MOD}!${modified}${NC} "
        [ "$untracked" -gt 0 ] && git_status="${git_status}${SEP}?${untracked}${NC} "
        [ "$deleted" -gt 0 ] && git_status="${git_status}${ERR}-${deleted}${NC} "
        git_status="${git_status% }"  # Remove trailing space

        git_info=" ${VCS}${GIT_ICON} ${branch}${NC}"
        [ -n "$git_status" ] && git_info="${git_info} ${SEP}[${NC}${git_status}${SEP}]${NC}"
    else
        git_info=" ${VCS}${GIT_ICON} ${branch}${NC}"
    fi
fi

# Output
context_info="${bar} ${context_percent}%"
echo -e "${DIR}${dir_name}${NC} ${SEP}|${NC} ${MODEL}${model_name}${NC} ${SEP}|${NC} ${context_info}${git_info:+ ${SEP}|${NC}}${git_info}"
