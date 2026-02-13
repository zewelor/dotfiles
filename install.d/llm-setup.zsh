#!/bin/zsh
#
# LLM Skills & Commands Setup
# Source of truth for LLM client configuration
# Sourced by install script, called via: make skills
#

# Setup LLM skills and commands for all supported clients
setup_llm_skills() {
  # Determine directories
  local install_d_dir="$(dirname "${(%):-%x}")"
  # Convert to absolute path in case script was sourced with relative path
  install_d_dir="$(cd "$install_d_dir" && pwd)"
  local base_dir="$(dirname "$install_d_dir")"
  local llms_dir="$base_dir/llms"
  # Check if llms is in prv/ subdirectory (privacy-sensitive configs)
  if [[ ! -d "$llms_dir" && -d "$base_dir/prv/llms" ]]; then
    llms_dir="$base_dir/prv/llms"
  fi
  local home_dir="$HOME"
  
  # Colors
  local color_red=$'\033[31m'
  local color_yellow=$'\033[33m'
  local color_reset=$'\033[0m'
  
  # Print banner helper (if print_banner not available)
  if ! typeset -f print_banner >/dev/null 2>&1; then
    print_banner() {
      local title="$1"
      local line="========================================"
      printf "\n%s\n%s\n%s\n" "$line" "$title" "$line"
    }
  fi
  
  # has() helper (if not available)
  if ! typeset -f has >/dev/null 2>&1; then
    has() {
      command -v "$1" >/dev/null 2>&1
    }
  fi
  
  print_banner "Setting up LLM skills and commands..."
  
  local has_claude=false
  local has_codex=false
  local has_opencode=false
  
  # Check Claude Code
  if has "claude"; then
    if [[ ! -d "$home_dir/.claude" ]]; then
      echo "${color_red}ERROR: Wykryto 'claude' ale brak ~/.claude/${color_reset}"
      echo "Uruchom najpierw: claude"
      exit 1
    fi
    has_claude=true
    echo "Claude Code wykryty: ~/.claude/"
  fi
  
  # Check Codex CLI
  if has "codex"; then
    if [[ ! -d "$home_dir/.codex" ]]; then
      echo "${color_red}ERROR: Wykryto 'codex' ale brak ~/.codex/${color_reset}"
      echo "Uruchom najpierw: codex"
      exit 1
    fi
    has_codex=true
    echo "Codex CLI wykryty: ~/.codex/"
  fi
  
  # Check OpenCode
  if has "opencode"; then
    has_opencode=true
    echo "OpenCode wykryty: ~/.agents/skills/ (native) oraz ~/.config/opencode/ (commands)"
  fi
  
  # Setup for Claude
  if [[ "$has_claude" == true ]]; then
    _setup_client_skills_and_commands "claude" "$llms_dir" "$home_dir"
  fi
  
  # Setup for Codex
  if [[ "$has_codex" == true ]]; then
    _setup_client_skills_and_commands "codex" "$llms_dir" "$home_dir"
  fi
  
  # Setup for opencode (native .agents skills and standard config commands)
  if [[ "$has_opencode" == true ]]; then
    # Native OpenCode skills
    _setup_client_skills_and_commands "agents" "$llms_dir" "$home_dir"
    # OpenCode config commands
    _setup_client_commands "opencode" "$llms_dir" "$home_dir"
  fi
  
  if [[ "$has_claude" == false && "$has_codex" == false && "$has_opencode" == false ]]; then
    echo "${color_yellow}Brak wykrytych klientów LLM (claude/codex/opencode)${color_reset}"
    echo "Skille i komendy nie zostały zalinkowane."
  fi
}

# Setup skills and commands for a specific client
_setup_client_skills_and_commands() {
  local client_name="$1"
  local llms_dir="$2"
  local home_dir="$3"
  local client_dir="$home_dir/.$client_name"
  
  # Setup skills
  local skills_source="$llms_dir/skills"
  local skills_target="$client_dir/skills"
  
  if [[ -d "$skills_source" ]]; then
    echo "Setting up skills for $client_name..."
    _symlink_skills_to_client "$skills_source" "$skills_target" "$client_name"
  fi
  
  # Setup commands
  local commands_source="$llms_dir/commands"
  local commands_target="$client_dir/commands"
  
  if [[ -d "$commands_source" ]]; then
    echo "Setting up commands for $client_name..."
    _symlink_commands_to_client "$commands_source" "$commands_target" "$client_name"
  fi
}

# Setup only commands for a client (for clients that don't support skills)
_setup_client_commands() {
  local client_name="$1"
  local llms_dir="$2"
  local home_dir="$3"
  local client_dir="$home_dir/.config/$client_name"
  
  local commands_source="$llms_dir/commands"
  local commands_target="$client_dir/commands"
  
  if [[ -d "$commands_source" ]]; then
    echo "Setting up commands for $client_name..."
    _symlink_commands_to_client "$commands_source" "$commands_target" "$client_name"
  fi
}

# Helper function to symlink skills from llms/skills/ to client directory
_symlink_skills_to_client() {
  local source_dir="$1"
  local target_dir="$2"
  local client_name="$3"
  
  setopt localoptions nullglob
  
  # Handle migration: if target_dir is a symlink (old stow setup), remove it
  if [[ -L "$target_dir" ]]; then
    echo "  Migracja: usuwanie starego symlinku $target_dir"
    rm "$target_dir"
  fi
  
  mkdir -p "$target_dir"
  
  # Clean up dead symlinks in target_dir
  for link in "$target_dir"/*; do
    if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
      echo "  Czyszczenie martwego symlinku: $(basename "$link")"
      rm "$link"
    fi
  done
  
  # Common skills - all clients get these
  if [[ -d "$source_dir/common" ]]; then
    if [[ -n "$(find "$source_dir/common" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]]; then
      echo "  Linkowanie wspólnych skilli do $client_name..."
      for skill_dir in "$source_dir/common"/*/; do
        if [[ -d "$skill_dir" ]]; then
          local skill_name=$(basename "$skill_dir")
          local target_link="$target_dir/$skill_name"
          
          if [[ -L "$target_link" ]]; then
            rm "$target_link"
          fi
          
          if [[ -d "$target_link" && ! -L "$target_link" ]]; then
            rm -rf "$target_link"
          fi
          
          ln -sfn "$skill_dir" "$target_link"
          echo "    + $skill_name (common)"
        fi
      done
    fi
  fi

  # Client-specific skills
  # Special case: 'agents' (OpenCode) also gets 'claude' skills for compatibility
  local skill_client_dir="$client_name"
  if [[ "$client_name" == "agents" ]]; then
    skill_client_dir="claude"
  fi

  if [[ -d "$source_dir/$skill_client_dir" ]]; then
    if [[ -n "$(find "$source_dir/$skill_client_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]]; then
      echo "  Linkowanie skilli specyficznych dla $skill_client_dir do $client_name..."
      for skill_dir in "$source_dir/$skill_client_dir"/*/; do
        if [[ -d "$skill_dir" ]]; then
          skill_name=$(basename "$skill_dir")
          target_link="$target_dir/$skill_name"
          
          if [[ -L "$target_link" ]]; then
            rm "$target_link"
          fi
          
          if [[ -d "$target_link" && ! -L "$target_link" ]]; then
            rm -rf "$target_link"
          fi
          
          ln -sfn "$skill_dir" "$target_link"
          echo "    + $skill_name ($skill_client_dir-specific)"
        fi
      done
    fi
  fi
  
  # Special case: opencode skills go to claude directory (compatibility)
  # and agents directory (native)
  if [[ ("$client_name" == "claude" || "$client_name" == "agents") && -d "$source_dir/opencode" ]]; then
    if [[ -n "$(find "$source_dir/opencode" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]]; then
      echo "  Linkowanie skilli OpenCode ($client_name)..."
      for skill_dir in "$source_dir/opencode"/*/; do
        if [[ -d "$skill_dir" ]]; then
          local skill_name=$(basename "$skill_dir")
          local target_link="$target_dir/$skill_name"
          
          if [[ -L "$target_link" ]]; then
            rm "$target_link"
          fi
          
          if [[ -d "$target_link" && ! -L "$target_link" ]]; then
            rm -rf "$target_link"
          fi
          
          ln -sfn "$skill_dir" "$target_link"
          echo "    + $skill_name (opencode-specific)"
        fi
      done
    fi
  fi
}

# Helper function to symlink commands from llms/commands/ to client directory
_symlink_commands_to_client() {
  local source_dir="$1"
  local target_dir="$2"
  local client_name="$3"

  setopt localoptions nullglob

  if [[ -L "$target_dir" ]]; then
    echo "Migracja: usuwanie starego symlinku $target_dir"
    rm "$target_dir"
  fi

  mkdir -p "$target_dir"

  # Clean up dead symlinks in target_dir
  for link in "$target_dir"/*; do
    if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
      echo "  Czyszczenie martwego symlinku: $(basename "$link")"
      rm "$link"
    fi
  done

  # Common commands - all clients get these
  if [[ -d "$source_dir/common" ]]; then
    if [[ -n "$(find "$source_dir/common" -maxdepth 1 -name '*.md' -type f 2>/dev/null)" ]]; then
      echo "Linkowanie wspólnych komend do $client_name..."
      for command_file in "$source_dir/common"/*.md; do
        if [[ -f "$command_file" ]]; then
          local command_name=$(basename "$command_file")
          local target_link="$target_dir/$command_name"

          if [[ -L "$target_link" ]]; then
            rm "$target_link"
          fi

          ln -sfn "$command_file" "$target_link"
          echo "  + $command_name (common)"
        fi
      done
    fi
  fi

  # Client-specific commands
  if [[ -d "$source_dir/$client_name" ]]; then
    if [[ -n "$(find "$source_dir/$client_name" -maxdepth 1 -name '*.md' -type f 2>/dev/null)" ]]; then
      echo "Linkowanie komend specyficznych dla $client_name..."
      for command_file in "$source_dir/$client_name"/*.md; do
        if [[ -f "$command_file" ]]; then
          local command_name=$(basename "$command_file")
          local target_link="$target_dir/$command_name"

          if [[ -L "$target_link" ]]; then
            rm "$target_link"
          fi

          ln -sfn "$command_file" "$target_link"
          echo "  + $command_name ($client_name-specific)"
        fi
      done
    fi
  fi
}



