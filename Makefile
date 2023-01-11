.PHONY: setup setup-vim packages

BASE=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ZINIT_COMMIT_SHA=7f6dc7da6c824b30c0e8e30ae0ecbda5be118e68

zinit_dir = ~/.zinit

all: base setup
base: packages setup-vim install-base-symlinks install-fonts | $(zinit_dir)

setup:
	git submodule update --init
	./install

setup-vim:
	./install-vim

install-fonts:
	mkdir -p ~/.fonts/

	for font in MesloLGS%20NF%20Regular.ttf MesloLGS%20NF%20Italic.ttf MesloLGS%20NF%20Bold.ttf MesloLGS%20NF%20Bold%20Italic.ttf; do \
		curl -s -L https://github.com/romkatv/dotfiles-public/blob/master/.local/share/fonts/NerdFonts/$$font?raw=true > ~/.fonts/$$font; \
	done

	fc-cache -vf ~/.fonts/

install-base-symlinks:
	for rc in .zshrc .tmux.conf .zshenv .p10k.zsh .vimrc .zsh; do \
		if [ ! -L ~/$$rc ]; then 																		\
			ln -sfv "$(BASE)/$$rc" ~/$$rc ;														\
		fi 																													\
	done

$(zinit_dir):
	mkdir -p $(zinit_dir)
	chmod g-rwX $(zinit_dir)
	git clone https://github.com/zdharma-continuum/zinit.git $(zinit_dir)/bin
	cd $(zinit_dir)/bin ; git reset --hard $(ZINIT_COMMIT_SHA)

packages:
	sudo apt-get install -y --no-install-recommends fontconfig vim subversion silversearcher-ag autoconf tmux zsh fd-find ncdu curl neovim jq

# appimage:
# 	lastversion -d $(HOME)/bin/Lens.AppImage lensapp/lens
# 	chmod +x $(HOME)/bin/Lens.AppImage
#
zinit_update:
	echo "Remember to update root also"
	zinit update
