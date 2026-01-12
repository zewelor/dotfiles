.PHONY: all install base update-fonts setup packages zinit_update doctor

BASE=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ZINIT_COMMIT_SHA=30514edc4a3e67229ce11306061ee92db9558cec

FONT_INSTALLER=$(BASE)/install-font
DOTFILES_FONTS_DIR=$(BASE)/.local/share/fonts
JETBRAINS_FONT_PACKAGE=JetBrainsMono
JETBRAINS_FONT_SUBFAMILY=JetBrainsMonoNLNerdFontMono

zinit_dir = $(HOME)/.zinit
zinit_script = $(zinit_dir)/bin/zinit.zsh

# List of packages to install (one per line for readability)
APT_PACKAGES_CORE= \
	git \
	fontconfig \
	unzip \
	autoconf \
	tmux \
	zsh \
	fd-find \
	ncdu \
	curl \
	jq \
	stow

APT_PACKAGES_OPTIONAL= \
	lazygit \
	duf \
	ripgrep

all: base setup

install: all
base: packages | $(zinit_script)

setup:
	-git submodule update --init
	./install

update-fonts:
	@echo "=========================="
	@echo "Syncing JetBrainsMonoNL Nerd Font (Mono) into dotfiles repo"
	@set -euo pipefail; \
	  DEST="$(DOTFILES_FONTS_DIR)"; \
	  mkdir -p "$$DEST"; \
	  USER_FONTS_DIR="$$DEST" FONT_CACHE_DIR="$$HOME/.local/share/fonts" FONT_CACHE_QUIET=1 \
	    "$(FONT_INSTALLER)" "$(JETBRAINS_FONT_PACKAGE)" "$(JETBRAINS_FONT_SUBFAMILY)";
	@echo "=========================="

$(zinit_script):
	@echo "=========================="
	@echo "Installing zinit"
	mkdir -p $(zinit_dir)
	chmod g-rwX $(zinit_dir)
	@if [ -e "$(zinit_dir)/bin" ] && [ ! -d "$(zinit_dir)/bin/.git" ]; then \
		echo "Error: $(zinit_dir)/bin exists but is not a git repo; please remove it and re-run."; \
		exit 1; \
	fi
	@if [ ! -d "$(zinit_dir)/bin/.git" ]; then \
		git clone https://github.com/zdharma-continuum/zinit.git $(zinit_dir)/bin; \
	fi
	cd $(zinit_dir)/bin ; git reset --hard $(ZINIT_COMMIT_SHA)
	@echo "=========================="

packages:
	sudo apt-get install -y --no-install-recommends $(APT_PACKAGES_CORE)
	-sudo apt-get install -y --no-install-recommends $(APT_PACKAGES_OPTIONAL)
	@echo "Checking available Neovim version..."
	@CANDIDATE=$$(LC_ALL=C apt-cache policy neovim | grep Candidate | awk '{print $$2}'); \
	if [ -z "$$CANDIDATE" ] || [ "$$CANDIDATE" = "(none)" ]; then \
		echo "Neovim not found in apt. Installing Vim..."; \
		sudo apt-get install -y --no-install-recommends vim; \
	elif dpkg --compare-versions "$$CANDIDATE" lt "0.8"; then \
		echo "Neovim version $$CANDIDATE is too old (< 0.8). Installing Vim..."; \
		sudo apt-get install -y --no-install-recommends vim; \
	else \
		echo "Neovim version $$CANDIDATE is sufficient (>= 0.8). Installing Neovim..."; \
		sudo apt-get install -y --no-install-recommends neovim; \
	fi

zinit_update:
	echo "Remember to update root also"
	zinit update

doctor:
	@echo "========================================"
	@echo "Dotfiles Health Check"
	@echo "========================================"
	@echo ""
	@echo "-> Checking shell script syntax..."
	@zsh -n install install-font .zshrc .zsh/*.zsh && echo "  OK: All scripts pass syntax check" || echo "  ERROR: Syntax errors found"
	@echo ""
	@echo "-> Checking stow dry-run..."
	@TMPDIR=$$(mktemp -d) && stow -n -t "$$TMPDIR" . 2>&1 | head -20; rmdir "$$TMPDIR" 2>/dev/null || true
	@echo "  (dry-run to temp target)"
	@echo ""
	@echo "-> Checking tool versions..."
	@printf "  git:   "; git --version 2>/dev/null | cut -d' ' -f3 || echo "not found"
	@printf "  zsh:   "; zsh --version 2>/dev/null | cut -d' ' -f2 || echo "not found"
	@printf "  nvim:  "; nvim --version 2>/dev/null | head -1 | grep -oE 'v[0-9.]+' || echo "not found"
	@printf "  stow:  "; stow --version 2>/dev/null | head -1 | grep -oE '[0-9.]+' || echo "not found"
	@printf "  tmux:  "; tmux -V 2>/dev/null | cut -d' ' -f2 || echo "not found"
	@echo ""
	@echo "========================================"
	@echo "Done"
	@echo "========================================"
