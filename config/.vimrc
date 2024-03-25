set ts=2
set softtabstop=2
set shiftwidth=2    " sets indentation 2 spaces
set expandtab       " tabs from spaces use CTRL_V_TAB to insert real tab
set ai
set nocin
set smartindent
set smarttab

set fileencodings=utf-8,default,latin1
set encoding=utf-8
set termencoding=utf-8
set viminfo='20,\"50  " read/write a .viminfo file, don't store more
                      " than 50 lines of registers
set history=50    " keep 50 lines of command line history
set bs=indent,eol,start " allow backspacing over everything in insert mode
set hidden " removes warning when switching between buffers without saving them first
set shortmess+=filmnrxoOtT      " abbrev. of messages (avoids 'hit enter')
filetype plugin indent on   " Automatically detect file types.
syntax on           " syntax highlighting
" Don't use the mouse.  At all.  For anything.  Let the terminal copy/paste!
set mouse=
set vb "makes visual bell instead of sound

set ruler   " show the cursor position all the time
"shows encoding of the file
set statusline=%<%f%h%m%r%=%b\ %{&encoding}\ 0x%B\ \ %l,%c%V\ %P
set laststatus=2

set nohls "no highlits for search
set incsearch "search incrementally
set ignorecase smartcase " ignore case if only small case letters are in search pattern

  if &diff
    colorscheme evening
endif
hi Comment    term=NONE cterm=NONE ctermfg=Cyan
hi Constant   ctermfg=gray
hi String     ctermfg=green
hi Folded     ctermbg=black ctermfg=green guibg=black guifg=green
hi FoldColumn guibg=black guifg=green
hi NonText    ctermfg=blue guifg=#4a4a59
hi SpecialKey ctermfg=blue guifg=#4a4a59
hi ExtraWhitespace ctermbg=red guibg=red

set wm=3
let &showbreak = '  '
" Format the paragraph that you are currently in:
map qP gqip}
" 'D' for delete: delete the rest of the file (ultimate in laziness; I don't       want to hold SHIFT.) :P
map qD dG
" Change text up to the next underscore (handy for ruby and perl)
map _ ct_
