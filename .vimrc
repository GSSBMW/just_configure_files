"-------------------------------------
"|		Vundle: manage plugins	     |
"-------------------------------------
set nocompatible              " be iMproved, required
filetype off                  " required

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()		" vundle#begin('~/some/path/here') to set path where Vundle shoule install plugins

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

Plugin 'scrooloose/nerdtree'

" OpenCL C syntax highlight
Plugin 'petRUShka/vim-opencl'

" Taglist 
Plugin 'taglist-plus'

call vundle#end()            " required
filetype plugin indent on    " required, 'filetype plugin on' to ignore plugin indent changes

" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ


"------------------------------------
"|			NERDTree				|
"------------------------------------
map <silent> <F3> : NERDTreeToggle<CR> 
let NERDTreeWinPos = "left"
let NERDTreeShowBookmarks = 1


"------------------------------------
"|			Tablist					|
"------------------------------------
map <F12> :!ctags -R --c++-kinds=+p --fields=+iaS --extra=+q<CR>
map <silent> <F4> : TlistToggle<CR>
let Tlist_Exit_OnlyWindow = 1
let Tlist_Use_Right_Window = 1
set tags=tags


"------------------------------------
"|			Basic Setting			|
"------------------------------------
set nocompatible    "not compatible with vi
set number          "line number
set hlsearch        "hilight search
set ruler
set showmode
set autoindent
syntax on
set nowrap

set tabstop=4       "insert 4 spaces for a tab
set softtabstop=4
set shiftwidth=4
set expandtab      "tab to spaces

set cursorline    "highlight current line
hi CursorLine cterm=none ctermbg=black ctermfg=NONE guibg=NONE guifg=NONE

set backspace=2
set encoding=utf-8
