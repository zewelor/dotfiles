.PHONY: all install base mise update-fonts setup packages zinit_update doctor verify skills test

BASE=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ZINIT_COMMIT_SHA=30514edc4a3e67229ce11306061ee92db9558cec
# renovate: datasource=github-release-attachments depName=jdx/mise versioning=semver-coerced
MISE_VERSION=v2026.8.10
MISE_INSTALLER_SHA256=b968bffadf07e0c820481f7c33aab119c814992e11e25d121ce7102bec8d71f1

FONT_INSTALLER=$(BASE)/install-font
HEALTHCHECK=$(BASE)/bin/dotfiles-health-check
DOTFILES_FONTS_DIR=$(BASE)/.local/share/fonts
MISE_BIN=$(HOME)/.local/bin/mise
JETBRAINS_FONT_PACKAGE=JetBrainsMono
JETBRAINS_FONT_SUBFAMILY=JetBrainsMonoNLNerdFontMono
JETBRAINS_FONT_STYLES=Regular,Bold,Italic,BoldItalic

zinit_dir = $(HOME)/.zinit
zinit_script = $(zinit_dir)/bin/zinit.zsh

# List of packages to install (one per line for readability)
APT_PACKAGES_CORE= \
	git \
	ca-certificates \
	fontconfig \
	unzip \
	autoconf \
	tmux \
	zsh \
	fd-find \
	ncdu \
	curl \
	btop \
	jq \
	stow \
	ripgrep \
	bc

APT_PACKAGES_OPTIONAL= \
	lazygit \
	duf \
	skopeo

all: base setup

install: all
base: packages | $(zinit_script)

mise: $(MISE_BIN)

setup:
	git submodule update --init -- .config/tmux/plugins/catppuccin/tmux
	./install

update-fonts:
	@echo "=========================="
	@echo "Syncing JetBrainsMonoNL Nerd Font (Mono) into dotfiles repo"
	@set -eu; \
	  DEST="$(DOTFILES_FONTS_DIR)"; \
	  mkdir -p "$$DEST"; \
	  USER_FONTS_DIR="$$DEST" FONT_CACHE_DIR="$$HOME/.local/share/fonts" FONT_CACHE_QUIET=1 \
	    "$(FONT_INSTALLER)" "$(JETBRAINS_FONT_PACKAGE)" "$(JETBRAINS_FONT_SUBFAMILY)" "$(JETBRAINS_FONT_STYLES)";
	@echo "=========================="

$(MISE_BIN):
	@echo "=========================="
	@echo "Installing mise"
	@set -eu; \
	  installer=$$(mktemp); \
	  trap 'rm -f "$$installer"' 0 HUP INT TERM; \
	  curl -fsSL "https://github.com/jdx/mise/releases/download/$(MISE_VERSION)/install.sh" -o "$$installer"; \
	  printf '%s  %s\n' "$(MISE_INSTALLER_SHA256)" "$$installer" | sha256sum -c -; \
	  MISE_VERSION="$(MISE_VERSION)" MISE_INSTALL_PATH="$(MISE_BIN)" sh "$$installer"
	@echo "=========================="

$(zinit_script): | packages
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
	elif dpkg --compare-versions "$$CANDIDATE" lt "0.11"; then \
		echo "Neovim version $$CANDIDATE is too old (< 0.11). Installing Vim..."; \
		sudo apt-get install -y --no-install-recommends vim; \
	else \
		echo "Neovim version $$CANDIDATE is sufficient (>= 0.11). Installing Neovim..."; \
		sudo apt-get install -y --no-install-recommends neovim; \
	fi

zinit_update:
	echo "Remember to update root also"
	zinit update

test:
	@zsh "$(BASE)/tests/vault_test.zsh"

doctor:
	@"$(HEALTHCHECK)" doctor

verify:
	@"$(HEALTHCHECK)" verify

# Refresh private stow links (including prv/.agents -> ~/.agents)
skills:
	@echo "========================================"
	@echo "Refreshing private stow links from prv/..."
	@echo "========================================"
	@stow -v -d prv -t "$(HOME)" .
