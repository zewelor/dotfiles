# https://github.com/logan-montellimard-braga/dotfiles/blob/3298e82cf25a2125ae9137b6bec9b8a540a10d46/.config/zsh/07-zstyle.zsh#L26
# https://github.com/search?q=zstyle+completion+menu+mp4&type=code&p=2

#
# Variables
#

# Standard style used by default for 'list-colors'
LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:bd=36;01:cd=33;01:su=31;40;07:sg=36;40;07:tw=32;40;07:ow=33;40;07:'}

# complete . and .. special directories
zstyle ':completion:*' special-dirs true

# enable caching to make completion for commands such as dpkg and apt usable
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zcompcache"

# group matches and describe
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:matches' group yes
zstyle ':completion:*:options' description yes
zstyle ':completion:*:options' auto-description 'specify: %d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# rehash if command not found (possibly recently installed)
zstyle ':completion:*' rehash true

# fuzzy match mistyped completions
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# directories
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true

## mplayer
zstyle ':completion:*:*:mplayer:*'           tag-order files
zstyle ':completion:*:*:mplayer:*'           file-patterns   \
       '*.(rmvb|mkv|mpg|wmv|mpeg|avi|flv|mp3|mp4|flac|ogg):video' \
       '*:all-files' '*(-/):directories'

## vim
zstyle ':completion:*:*:(vim|rview|vimdiff|xxd):*:*files' \
  ignored-patterns '*~|*.(old|bak|zwc|viminfo|rxvt-*|zcompdump)|pm_to_blib|cover_db|blib' \
  file-sort modification
zstyle ':completion:*:*:(vim|rview|vimdiff|xxd):*' \
  file-sort modification
zstyle ':completion:*:*:(vim|rview|vimdiff|xxd):*' \
  tag-order files

# ignores unavailable commands
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

# completion element sorting
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# man
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# make completion is slow
zstyle ':completion:*:make:*:targets' call-command true
zstyle ':completion:*:make::' tag-order targets:
zstyle ':completion:*:*:*make:*:targets' command awk \''/^[a-zA-Z0-9][^\/\t=]+:/ {print $1}'\' \$file

# history
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# ignore multiple entries
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# ssh/scp/rsync
zstyle ':completion:*:(ssh|scp|ftp|sftp):*' hosts $hosts
zstyle ':completion:*:(ssh|scp|ftp|sftp):*' users $users

## users
zstyle ':completion:*:*:*:users' ignored-patterns \
        adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
        dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
        hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
        mailman mailnull mldonkey mysql nagios \
        named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
        operator pcap postfix postgres privoxy pulse pvm quagga radvd \
        rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs
zstyle '*' single-ignored show
