set nocompatible
set encoding=utf-8
scriptencoding utf-8

filetype plugin indent on
syntax enable

set background=dark
if has('termguicolors')
  set termguicolors
endif

set number
set numberwidth=4
set cursorline
set signcolumn=yes
set foldcolumn=1
set fillchars=fold:\ ,vert:│
set ruler
set showcmd
set showmode
set laststatus=2
set showtabline=0
set noshowmode
set title
set hidden
set mouse=a
set clipboard=unnamedplus
set updatetime=300
set timeoutlen=450
set ttimeoutlen=20
set scrolloff=5
set sidescrolloff=8
set splitbelow
set splitright
set wildmenu
set wildmode=longest:full,full
set wildignorecase
set ignorecase
set smartcase
set incsearch
set hlsearch
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set smartindent
set autoindent
set backspace=indent,eol,start
set completeopt=menuone,noinsert,noselect
set shortmess+=c
set tags=./tags;,tags
set path+=**

highlight StatusLine cterm=bold ctermbg=24 ctermfg=15 guibg=#2F3549 guifg=#C0CAF5
highlight StatusLineNC ctermbg=236 ctermfg=244 guibg=#1A1B26 guifg=#565F89
highlight Normal ctermbg=234 ctermfg=15 guibg=#1A1B26 guifg=#C0CAF5
highlight NonText ctermbg=234 ctermfg=8 guibg=#1A1B26 guifg=#565F89
highlight EndOfBuffer ctermbg=234 ctermfg=8 guibg=#1A1B26 guifg=#565F89
highlight LineNr ctermbg=235 ctermfg=3 guibg=#202436 guifg=#D7A65F
highlight CursorLineNr cterm=bold ctermbg=24 ctermfg=15 guibg=#2F3549 guifg=#C0CAF5
highlight SignColumn ctermbg=235 ctermfg=8 guibg=#202436 guifg=#565F89
highlight FoldColumn ctermbg=235 ctermfg=8 guibg=#202436 guifg=#565F89
highlight CursorLineSign ctermbg=24 guibg=#2F3549
highlight CursorLineFold ctermbg=24 guibg=#2F3549
highlight CursorLine ctermbg=236 guibg=#24283B
highlight User1 cterm=bold ctermfg=81 ctermbg=24 guifg=#7DCFFF guibg=#2F3549
highlight User2 cterm=bold ctermfg=221 ctermbg=24 guifg=#E0AF68 guibg=#2F3549
highlight User3 ctermfg=151 ctermbg=24 guifg=#9ECE6A guibg=#2F3549
highlight User4 cterm=bold ctermfg=117 ctermbg=236 guifg=#7AA2F7 guibg=#24283B
highlight User5 cterm=bold ctermfg=152 ctermbg=236 guifg=#B4F9F8 guibg=#24283B
highlight User6 cterm=bold ctermfg=16 ctermbg=75 guifg=#1A1B26 guibg=#7AA2F7
highlight WinBar cterm=bold ctermbg=236 ctermfg=15 guibg=#24283B guifg=#C0CAF5
highlight WinBarNC ctermbg=234 ctermfg=244 guibg=#1A1B26 guifg=#565F89

function! CurrentCodeContext() abort
  let l:class = ''
  let l:func = ''
  let l:line_number = line('.')

  for l:idx in reverse(range(1, l:line_number))
    let l:line = getline(l:idx)

    if empty(l:func)
      let l:match = matchlist(l:line, '^\s*\%(async\s\+\)\?\%(function\|def\|fn\|func\|sub\|proc\)\s\+\([A-Za-z_][A-Za-z0-9_:.<>-]*\)')
      if !empty(l:match)
        let l:func = l:match[1]
      else
        let l:match = matchlist(l:line, '^\s*\%(\%(public\|private\|protected\|static\|final\|export\|async\|const\|let\|var\|override\|virtual\|inline\|extern\)\s\+\)*\([A-Za-z_][A-Za-z0-9_:<>*& ]*\)\s\+\([A-Za-z_][A-Za-z0-9_]*\)\s*(.*)\s*\%(const\s*\)\?\({\|$\)')
        if !empty(l:match)
          let l:func = l:match[3]
        endif
      endif
    endif

    if empty(l:class)
      let l:match = matchlist(l:line, '^\s*\%(class\|struct\|interface\|enum\|trait\|namespace\|impl\)\s\+\([A-Za-z_][A-Za-z0-9_:.<>-]*\)')
      if !empty(l:match)
        let l:class = l:match[1]
      endif
    endif

    if !empty(l:class) && !empty(l:func)
      break
    endif
  endfor

  if !empty(l:class) && !empty(l:func)
    return l:class . ' > ' . l:func . '()'
  endif
  if !empty(l:func)
    return l:func . '()'
  endif
  if !empty(l:class)
    return l:class
  endif
  return expand('%:t')
endfunction

function! ModeLabel() abort
  let l:mode = mode(1)
  if l:mode =~# '^i'
    return 'INSERT'
  endif
  if l:mode =~# '^R'
    return 'REPLACE'
  endif
  if l:mode =~# '^v\|^V\|^\x16'
    return 'VISUAL'
  endif
  if l:mode ==# 'c'
    return 'COMMAND'
  endif
  return 'NORMAL'
endfunction

function! SetModeAccent(mode_name) abort
  if a:mode_name ==# 'insert'
    highlight User6 cterm=bold ctermfg=16 ctermbg=114 guifg=#1A1B26 guibg=#9ECE6A
    highlight CursorLineNr cterm=bold ctermbg=28 ctermfg=15 guibg=#33543F guifg=#C0CAF5
    return
  endif
  if a:mode_name ==# 'replace'
    highlight User6 cterm=bold ctermfg=16 ctermbg=203 guifg=#1A1B26 guibg=#F7768E
    highlight CursorLineNr cterm=bold ctermbg=52 ctermfg=15 guibg=#5A2E3A guifg=#C0CAF5
    return
  endif
  highlight User6 cterm=bold ctermfg=16 ctermbg=75 guifg=#1A1B26 guibg=#7AA2F7
  highlight CursorLineNr cterm=bold ctermbg=24 ctermfg=15 guibg=#2F3549 guifg=#C0CAF5
endfunction

augroup WeztermEditorModeAccent
  autocmd!
  autocmd InsertEnter * call SetModeAccent('insert')
  autocmd InsertLeave * call SetModeAccent('normal')
  autocmd VimEnter,WinEnter,BufEnter * call SetModeAccent('normal')
augroup END

call SetModeAccent('normal')

set statusline=%#User6#\ %{ModeLabel()}\ 
set statusline+=%#User1#\ %f\ %m%r%h%w\ 
set statusline+=%#User2#%{CurrentCodeContext()}\ 
set statusline+=%=
set statusline+=%#User3#\ %y\ %{&fileencoding==''?&encoding:&fileencoding}\ [%l:%c]\ 

if exists('+winbar')
  set winbar=
endif

function! ProjectRoot() abort
  let l:markers = ['.git', 'compile_commands.json', 'CMakeLists.txt', 'pyproject.toml', 'setup.py', 'package.json', 'go.mod', 'Cargo.toml']
  let l:dir = expand('%:p:h')
  if empty(l:dir)
    let l:dir = getcwd()
  endif

  while !empty(l:dir)
    for l:marker in l:markers
      if !empty(globpath(l:dir, l:marker, 0, 1))
        return l:dir
      endif
    endfor

    let l:parent = fnamemodify(l:dir, ':h')
    if l:parent ==# l:dir
      break
    endif
    let l:dir = l:parent
  endwhile

  return getcwd()
endfunction

function! TagsRefresh() abort
  if !executable('ctags')
    echohl ErrorMsg
    echo 'ctags not found in PATH'
    echohl None
    return
  endif

  let l:root = ProjectRoot()
  let l:tagfile = l:root . '/tags'
  execute 'silent !ctags -R --fields=+n --extras=+q -f ' . shellescape(l:tagfile) . ' ' . shellescape(l:root)
  redraw!
  echo 'tags refreshed: ' . l:tagfile
endfunction

command! TagsRefresh call TagsRefresh()

function! ToWindowsPath(path) abort
  if executable('cygpath')
    let l:converted = system(['cygpath', '-w', a:path])
    if v:shell_error == 0
      return trim(l:converted)
    endif
  endif
  return a:path
endfunction

function! ToVimPath(path) abort
  if executable('cygpath') && a:path =~# '^\a:[\\/]'
    let l:converted = system(['cygpath', '-u', a:path])
    if v:shell_error == 0
      return trim(l:converted)
    endif
  endif
  return a:path
endfunction

function! WeztermConfigRoot() abort
  if exists('g:wezterm_editor_config_root') && !empty(g:wezterm_editor_config_root)
    return g:wezterm_editor_config_root
  endif
  if !empty($WEZTERM_CONFIG_ROOT)
    return $WEZTERM_CONFIG_ROOT
  endif
  return ToWindowsPath(expand('~/.wezterm-config/wezterm'))
endfunction

function! SymbolJump(target) abort
  let l:file = expand('%:p')
  if empty(l:file)
    echohl ErrorMsg
    echo 'no file for semantic jump'
    echohl None
    return
  endif

  let l:script = WeztermConfigRoot() . '\scripts\jump-to-definition.ps1'
  let l:cmd = [
        \ 'powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        \ '-File', l:script,
        \ '-Root', ProjectRoot(),
        \ '-Symbol', expand('<cword>'),
        \ '-Target', a:target,
        \ '-File', l:file,
        \ '-Line', string(line('.')),
        \ '-Column', string(col('.')),
        \ '-NoOpen'
        \ ]
  let l:output = system(l:cmd)
  if v:shell_error != 0
    echohl ErrorMsg
    echo trim(l:output)
    echohl None
    return
  endif

  let l:lines = filter(split(l:output, "\n"), 'v:val !~# "^\\s*$"')
  if empty(l:lines)
    echohl ErrorMsg
    echo 'no location returned'
    echohl None
    return
  endif

  let l:match = matchlist(l:lines[-1], '^\(.*\):\(\d\+\)\%(:\(\d\+\)\)\?$')
  if empty(l:match)
    echohl ErrorMsg
    echo l:lines[-1]
    echohl None
    return
  endif

  let l:target_path = ToVimPath(l:match[1])
  let l:target_line = str2nr(l:match[2])
  let l:target_col = empty(l:match[3]) ? 1 : str2nr(l:match[3])
  execute 'edit +' . l:target_line . ' ' . fnameescape(l:target_path)
  call cursor(l:target_line, l:target_col)
  normal! zz
endfunction

command! SymbolDefinition call SymbolJump('Definition')
command! SymbolDeclaration call SymbolJump('Declaration')

nnoremap <silent> <Esc><Esc> :nohlsearch<CR>
nnoremap <C-s> :write<CR>
inoremap <C-s> <Esc>:write<CR>a
nnoremap <C-p> :find *
nnoremap <leader>tg :TagsRefresh<CR>
nnoremap gd :SymbolDefinition<CR>
nnoremap gD :SymbolDeclaration<CR>
nnoremap <leader>gd :SymbolDefinition<CR>
nnoremap <leader>gD :SymbolDeclaration<CR>
