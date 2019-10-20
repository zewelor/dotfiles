.PHONY: setup setup-vim packages

all: packages setup setup-vim install-zplugin

setup:
	./install

setup-vim:
	./install-vim

install-zplugin:
	mkdir -p ~/.zplugin
	chmod g-rwX "${HOME}/.zplugin"
	git clone https://github.com/zdharma/zplugin.git ~/.zplugin/bin

packages:
	sudo apt-get install -y --no-install-recommends vim subversion silversearcher-ag autoconf tmux zsh
