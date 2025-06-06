let mapleader      = ' '
let maplocalleader = ' '

set pastetoggle=<F3>

" Use Vim settings, rather then Vi settings (much better!).
" " This must be first, because it changes other options as a side effect.
set nocompatible

" ================ Undofile ======================
set undodir=~/.vim/undo
set undofile
set undolevels=1000 "maximum number of changes that can be undone
set undoreload=10000 "maximum number lines to save for undo on a buffer reload

" ================ Swap Files ======================
set directory=~/.vim/swapfiles
set backupdir=~/.vim/backupfiles

" ================ Indentation ======================
set autoindent
set smartindent
set smarttab
set shiftwidth=2
set softtabstop=2
set tabstop=2
set expandtab

" ================ Search ===========================
set incsearch       " Find the next match as we type the search
set hlsearch        " Highlight searches by default
set ignorecase      " Ignore case when searching...
set smartcase       " ...unless we type a capital

set number

syntax on             " Enable syntax highlighting
filetype on           " Enable filetype detection
filetype indent on    " Enable filetype-specific indenting
filetype plugin on    " Enable filetype-specific plugins

" ================ Turn Off Swap Files ==============
"
" set nobackup
" set nowb

map <C-s> <esc>:w<CR>
imap <C-s> <esc>:w<CR>

" Quit
nnoremap <Leader>q :q<cr>
nnoremap <Leader>Q :qa!<cr>

" <F10> | NERD Tree
inoremap <F10> <esc>:NERDTreeToggle<cr>
nnoremap <F10> :NERDTreeToggle<cr>

" Toggle line numbers with Ctrl + N
:nmap <C-N><C-N> :set invnumber<CR>

" ----------------------------------------------------------------------------
" <tab> / <s-tab> | Circular windows navigation
" ----------------------------------------------------------------------------
nnoremap <tab>   <c-w>w
nnoremap <S-tab> <c-w>W

" ----------------------------------------------------------------------------
" vim-fugitive
" ----------------------------------------------------------------------------
" nmap     <Leader>g :Gstatus<CR>gg<c-n>
" nnoremap <Leader>d :Gdiff<CR>

" ----------------------------------------------------------------------------
" vim-easy-align
" ----------------------------------------------------------------------------
" Start interactive EasyAlign in visual mode (e.g. vip<Enter>)
vmap <Enter> <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" ============================================================================
" VIM-PLUG BLOCK {{{
" ============================================================================

call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

Plug 'pbrisbin/vim-mkdir'

" Colors
Plug 'chriskempson/vim-tomorrow-theme'
Plug 'altercation/vim-colors-solarized'
" Plug 'bling/vim-airline'

" Edit
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-endwise'
Plug 'vim-scripts/tComment'
Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'ervandew/supertab'

" Browsing
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle'    }
Plug 'kien/ctrlp.vim'
Plug '~/.zplugin/plugins/junegunn---fzf'
Plug 'junegunn/fzf.vim'

Plug 'junegunn/vim-easy-align'
Plug 'michaeljsmith/vim-indent-object'
Plug 'github/copilot.vim'
Plug 'NoahTheDuke/vim-just'

" Git
" Plug 'tpope/vim-fugitive'
Plug 'gregsexton/gitv', { 'on': 'Gitv' }

call plug#end()

colorscheme solarized
" colorscheme Tomorrow-Night
set background=light

" Local config
if filereadable($HOME . "/.vimrc.local")
  source ~/.vimrc.local
endif

autocmd FileType python set softtabstop=2
autocmd FileType python set shiftwidth=2
