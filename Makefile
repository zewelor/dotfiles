.PHONY: setup setup-vim packages

all: packages setup setup-vim

setup:
	./install

setup-vim:
	./install-vim

packages:
	sudo apt-get install -y --no-install-recommends vim subversion silversearcher-ag autoconf tmux zsh
