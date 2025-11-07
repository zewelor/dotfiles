.PHONY: all base install-fonts setup packages $(zinit_dir) zinit_update

BASE=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ZINIT_COMMIT_SHA=30514edc4a3e67229ce11306061ee92db9558cec

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

install-fonts:
	@echo "=========================="
	@echo "Installing official Nerd Fonts (FiraCode + Symbols)"
	@set -euo pipefail; \
	  NF_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"; \
	  DEST="$$HOME/.local/share/fonts/NerdFonts"; \
	  mkdir -p "$$DEST"; \
	  command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }; \
	  command -v unzip >/dev/null || { echo "unzip required" >&2; exit 1; }; \
	  command -v fc-cache >/dev/null || { echo "fontconfig (fc-cache) required" >&2; exit 1; }; \
	  echo "[fonts] Downloading FiraCode.zip …"; \
	  curl -fsSLo "$$DEST/FiraCode.zip" "$$NF_BASE/FiraCode.zip"; \
	  echo "[fonts] Downloading NerdFontsSymbolsOnly.zip …"; \
	  curl -fsSLo "$$DEST/Symbols.zip" "$$NF_BASE/NerdFontsSymbolsOnly.zip"; \
	  echo "[fonts] Extracting …"; \
	  unzip -oq "$$DEST/FiraCode.zip" -d "$$DEST"; \
	  unzip -oq "$$DEST/Symbols.zip" -d "$$DEST"; \
	  rm -f "$$DEST/FiraCode.zip" "$$DEST/Symbols.zip"; \
	  echo "[fonts] Refreshing font cache …"; \
	  fc-cache -f "$$HOME/.local/share/fonts" >/dev/null || fc-cache -f; \
	  echo "[fonts] Done. Restart terminal and apps to apply."
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
