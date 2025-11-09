.PHONY: all base install-fonts dotfiles-fonts setup packages $(zinit_dir) zinit_update

BASE=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ZINIT_COMMIT_SHA=30514edc4a3e67229ce11306061ee92db9558cec

FONT_INSTALLER=$(BASE)/install-font
DOTFILES_FONTS_DIR=$(BASE)/.local/share/fonts
JETBRAINS_FONT_PACKAGE=JetBrainsMono
JETBRAINS_FONT_SUBFAMILY=NerdFontMono

zinit_dir = ~/.zinit

# List of packages to install (one per line for readability)
APT_PACKAGES= \
	fontconfig \
	unzip \
	vim \
	autoconf \
	tmux \
	zsh \
	fd-find \
	ncdu \
	curl \
	jq \
	stow \
	lazygit \
	ripgrep

all: base setup
base: packages install-fonts | $(zinit_dir)

setup:
	-git submodule update --init
	./install

dotfiles-fonts:
	@echo "=========================="
	@echo "Syncing JetBrainsMono Nerd Font (Mono) into dotfiles repo"
	@set -euo pipefail; \
	  DEST="$(DOTFILES_FONTS_DIR)"; \
	  mkdir -p "$$DEST"; \
	  USER_FONTS_DIR="$$DEST" FONT_CACHE_DIR="$$HOME/.local/share/fonts" \
	    "$(FONT_INSTALLER)" "$(JETBRAINS_FONT_PACKAGE)" "$(JETBRAINS_FONT_SUBFAMILY)"; \
	  if [ ! -e "$$HOME/.local/share/fonts" ]; then \
	    echo "[fonts] Tip: run ./install to stow $$DEST into $$HOME/.local/share/fonts"; \
	  elif [ "$(readlink -f "$$HOME/.local/share/fonts" 2>/dev/null)" != "$$DEST" ]; then \
	    echo "[fonts] Warning: $$HOME/.local/share/fonts isn't pointing at $$DEST yet (run ./install)."; \
	  else \
	    echo "[fonts] Verified: $$HOME/.local/share/fonts is managed by dotfiles."; \
	  fi
	@echo "=========================="

$(zinit_dir):
	@echo "=========================="
	@echo "Installing zinit"

	mkdir -p $(zinit_dir)
	chmod g-rwX $(zinit_dir)
	git clone https://github.com/zdharma-continuum/zinit.git $(zinit_dir)/bin
	cd $(zinit_dir)/bin ; git reset --hard $(ZINIT_COMMIT_SHA)
	@echo "=========================="

packages:
	sudo apt-get install -y --no-install-recommends $(APT_PACKAGES)
	sudo snap install nvim --classic

zinit_update:
	echo "Remember to update root also"
	zinit update
