.PHONY: setup packages $(zinit_dir) zinit_update

BASE=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ZINIT_COMMIT_SHA=30514edc4a3e67229ce11306061ee92db9558cec

zinit_dir = ~/.zinit

# List of packages to install (one per line for readability)
APT_PACKAGES = \
	fontconfig \
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
	@echo "Installing MesloLGS NF font"

	mkdir -p ~/.fonts/

	for font in MesloLGS%20NF%20Regular.ttf MesloLGS%20NF%20Italic.ttf MesloLGS%20NF%20Bold.ttf MesloLGS%20NF%20Bold%20Italic.ttf; do \
		curl -s -L https://github.com/romkatv/dotfiles-public/blob/master/.local/share/fonts/NerdFonts/$$font?raw=true > ~/.fonts/$$font; \
	done

	fc-cache -vf ~/.fonts/
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

zinit_update:
	echo "Remember to update root also"
	zinit update
