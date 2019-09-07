.PHONY: setup plugins

define ZSH_PLUGINS_FILE_HEADER
#!/usr/bin/env zsh

# This file was generated by antibody (https://github.com/getantibody/antibody).
# Do not edit it directly but instead run "cd ~/dotfiles", update zsh_plugins.txt
# and then run "make plugins".

endef
export ZSH_PLUGINS_FILE_HEADER

setup:
	./install

plugins:
	@echo "$$ZSH_PLUGINS_FILE_HEADER" > ~/.zsh_plugins.sh
	@antibody bundle < zsh_plugins.txt >> ~/.zsh_plugins.sh
	@antibody bundle < ~/.zsh_plugins.local >> ~/.zsh_plugins.sh
	@echo "Zsh plugins installed"
