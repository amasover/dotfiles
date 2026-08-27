syntax on
inoremap fd <Esc>
" Overwrite the default cut command so that it goes to
" the system clipboard (unnamedplus). This should be the
" default behavior of 'dd', since the clipboard is set to
" 'unnamedplus', but for some reason it's not.
nnoremap <expr> dd (v:register ==# '"' ? '"+' : '') . 'dd'
set laststatus=2
set clipboard=unnamedplus
let mapleader=" "
" " Copy to clipboard

vnoremap  <leader>y  "+y
nnoremap  <leader>Y  "+yg_
nnoremap  <leader>y  "+y
nnoremap  <leader>yy  "+yy

" " Paste from clipboard
nnoremap <leader>p "+p
nnoremap <leader>P "+P
vnoremap <leader>p "+p
vnoremap <leader>P "+P
set clipboard^=unnamedplus
" set laststatus=2
" set clipboard=unnamedplus
" let mapleader=" "
" " " Copy to clipboard

" vnoremap  <leader>y  "+y
" nnoremap  <leader>Y  "+yg_
" nnoremap  <leader>y  "+y
" nnoremap  <leader>yy  "+yy

" " " Paste from clipboard
" nnoremap <leader>p "+p
" nnoremap <leader>P "+P
" vnoremap <leader>p "+p
" vnoremap <leader>P "+P
" uncomment the line below if powerline installed with python3
" let g:powerline_pycmd = 'py3'

"""""""""""""""""""""""""""""""""""
"                                  "
"             VIM-PLUG             "
"                                  "
"""""""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')

" Plugins without acceptable Arch/AUR packages.
Plug 'tpope/vim-repeat'
Plug 'hashivim/vim-terraform'
Plug 'svermeulen/vim-easyclip'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

" :PlugInstall installs missing plugins; :PlugUpdate advances them.
" :PlugDiff reviews updates; :PlugClean removes undeclared plugins.
let g:airline_theme = 'nord_minimal'
let g:airline_powerline_fonts = 1

set termguicolors
colorscheme nord
set number
set tabstop=4
set shiftwidth=4
set expandtab
" highlight search matches
set hlsearch

nmap <Ctrl-V><Del> x
imap <Ctrl-V><Del> <Ctrl-V><Esc>lxi
