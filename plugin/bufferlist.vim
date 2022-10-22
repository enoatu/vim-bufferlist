"
"== VIM BUFFER LIST SCRIPT 1.3 ================================================
"= Copyright(c) 2005, Robert Lillack <rob@lillack.de>                          =
"= Redistribution in any form with or without modification permitted.          =
"=                                                                             =
"= INFORMATION =================================================================
"= Upon keypress this script display a nice list of buffers on the left, which =
"= can be selected with mouse or keyboard. As soon as a buffer is selected     =
"= (Return, double click) the list disappears.                                 =
"= The selection can be cancelled with the same key that is configured to open =
"= the list or by pressing 'q'. Movement key and mouse (wheel) should work as  =
"= one expects.                                                                =
"= Buffers that are visible (in any window) are marked with '*', ones that are =
"= Modified are marked with '+'                                                =
"= To delete a buffer from the list (i.e. close the file) press 'd'.           =
"=                                                                             =
"= USAGE =======================================================================
"= Put this file into you ~/.vim/plugin directory and set up up like this in   =
"= your ~/.vimrc:                                                              =
"=                                                                             =
"= NEEDED:                                                                     =
"=     map <silent> <F3> :call BufferList()<CR>                                =
"= OPTIONAL:                                                                   =
"=     let g:BufferListWidth = 25                                              =
"=     let g:BufferListMaxWidth = 50                                           =
"=     hi BufferSelected term=reverse ctermfg=white ctermbg=red cterm=bold     =
"=     hi BufferNormal term=NONE ctermfg=black ctermbg=darkcyan cterm=NONE     =
"===============================================================================

if exists('g:BufferListLoaded')
  finish
endif
let g:BufferListLoaded = 1

if !exists('g:BufferListWidth')
  let g:BufferListWidth = 20
endif

if !exists('g:BufferListMaxWidth')
  let g:BufferListMaxWidth = 40
endif

function GenerateHexColor(seed)
  let hex = '789ABCDE'
  let color = ''
  let number = a:seed
  for i in range(6)
	let color .= hex[number % 8]
	let number /= 16
  endfor
  return color
endfunction

function! GenerateRandomColor(name)
  let l:seed = GenerateSeedIDFromString(a:name)
  echo l:seed
  return '#' . GenerateHexColor(l:seed)
endfunction

function GenerateSeedIDFromString(name)
  let l:id = sha256(a:name)
  let l:number = filter(split(l:id, '\zs'), { idx, char -> char >= '0' && char <= '9' })
  return join(l:number, "")[0:9]
endfunction

function! EscapteSlash(name)
  return substitute(a:name, '/', '\\/', 'g')
endfunction

" toggled the buffer list on/off
function! BufferList()
  " if we get called and the list is open --> close it
  if bufexists(bufnr("__BUFFERLIST__"))
    exec ':' . bufnr("__BUFFERLIST__") . 'bwipeout'
    return
  endif

  let l:bufcount = bufnr('$')
  let l:displayedbufs = 0
  let l:activebuf = bufnr('')
  let l:activebufline = 0
  let l:buflist = ''
  let l:bufnumbers = ''
  let l:width = g:BufferListWidth

  let l:sortbuflist = []
  let l:i = 0 | while l:i <= l:bufcount | let l:i = l:i + 1
    let l:bufname = bufname(l:i)
    call add(l:sortbuflist, l:bufname)
  endwhile

  call sort(l:sortbuflist)

  "adjust empty
  call remove(l:sortbuflist, 0)
  call insert(l:sortbuflist, "", l:bufcount)

  let l:sortbufaddress = []
  let l:i = 0 | while l:i <= l:bufcount | let l:i = l:i + 1
    let l:bufaddress = bufnr(l:sortbuflist[l:i - 1])
    call add(l:sortbufaddress, l:bufaddress)
  endwhile

  "adjust empty
  call remove(l:sortbufaddress, l:bufcount)
  call insert(l:sortbufaddress, 0, l:bufcount)

  " iterate through the buffers
  let l:i = 0 | while l:i <= l:bufcount | let l:i = l:i + 1
    let l:bufname = l:sortbuflist[l:i - 1]
    let l:bufadr = l:sortbufaddress[l:i - 1]
    if strlen(l:bufname)
      \&& getbufvar(l:bufadr, '&modifiable')
      \&& getbufvar(l:bufadr, '&buflisted')

      " adapt width and/or buffer name
      if l:width < (strlen(l:bufname) + 5)
        if strlen(l:bufname) + 5 < g:BufferListMaxWidth
          let l:width = strlen(l:bufname) + 5
        else
          let l:width = g:BufferListMaxWidth
          let l:bufname = '...' . strpart(l:bufname, strlen(l:bufname) - g:BufferListMaxWidth + 8)
        endif
      endif

      if bufwinnr(l:bufadr) != -1
        let l:bufname = l:bufname . '*'
      endif
      if getbufvar(l:bufadr, '&modified')
        let l:bufname = l:bufname . '+'
      endif
      " count displayed buffers
      let l:displayedbufs = l:displayedbufs + 1
      " remember buffer numbers
      let l:bufnumbers = l:bufnumbers . l:bufadr . ':'
      " remember the buffer that was active BEFORE showing the list
      if l:activebuf == l:bufadr
        let l:activebufline = l:displayedbufs
      endif
      " fill the name with spaces --> gives a nice selection bar
      " use MAX width here, because the width may change inside of this 'for' loop
      while strlen(l:bufname) < g:BufferListMaxWidth
        let l:bufname = l:bufname . ' '
      endwhile
      " add the name to the list
      let l:buflist = l:buflist . '  ' .l:bufname . "\n"
    endif
  endwhile

  " generate a variable to fill the buffer afterwards
  " (we need this for "full window" color :)
  let l:fill = "\n"
  let l:i = 0 | while l:i < l:width | let l:i = l:i + 1
    let l:fill = ' ' . l:fill
  endwhile
  
  " now, create the buffer & set it up
  exec 'silent! ' . l:width . 'vne __BUFFERLIST__'
  setlocal noshowcmd
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nowrap
  setlocal nonumber
  " disable list setting(trail etc.)
  setlocal nolist

  " set up syntax highlighting
  if has("syntax")
    syn clear
    for i in range(len(l:sortbuflist))
      if l:sortbuflist[i] == ""
        continue
      endif
      let l:hash = GenerateRandomColor(l:sortbuflist[i])
      execute 'syn match bufferlist' . i . ' /' . EscapteSlash(l:sortbuflist[i]) . '/'
      execute 'hi def bufferlist' . i . ' ctermfg=168 ctermbg=16 guifg=' . l:hash . ' guibg=#282c34'
    endfor
  endif

  setlocal modifiable
  if l:displayedbufs > 0
    " input the buffer list, delete the trailing newline, & fill with blank lines
    put! =l:buflist
    " is there any way to NOT delete into a register? bummer...
    "norm Gdd$
    norm GkJ
    while winheight(0) > line(".")
      put =l:fill
    endwhile
  else
    let l:i = 0 | while l:i < winheight(0) | let l:i = l:i + 1
      put! =l:fill
    endwhile
    norm 0
  endif
  setlocal nomodifiable

  " set up the keymap
  noremap <silent> <buffer> <CR> :call LoadBuffer()<CR>
  map <silent> <buffer> q :bwipeout<CR> 
  map <silent> <buffer> j :call BufferListMove("down")<CR>
  map <silent> <buffer> k :call BufferListMove("up")<CR>
  map <silent> <buffer> d :call BufferListDeleteBuffer()<CR>
  map <silent> <buffer> <MouseDown> :call BufferListMove("up")<CR>
  map <silent> <buffer> <MouseUp> :call BufferListMove("down")<CR>
  map <silent> <buffer> <LeftDrag> <Nop>
  map <silent> <buffer> <LeftRelease> :call BufferListMove("mouse")<CR>
  map <silent> <buffer> <2-LeftMouse> :call BufferListMove("mouse")<CR>
    \:call LoadBuffer()<CR>
  map <silent> <buffer> <Down> j
  map <silent> <buffer> <Up> k
  map <buffer> h <Nop>
  map <buffer> l <Nop>
  map <buffer> <Left> <Nop>
  map <buffer> <Right> <Nop>
  map <buffer> i <Nop>
  map <buffer> a <Nop>
  map <buffer> I <Nop>
  map <buffer> A <Nop>
  map <buffer> o <Nop>
  map <buffer> O <Nop>
  map <silent> <buffer> <Home> :call BufferListMove(1)<CR>
  map <silent> <buffer> <End> :call BufferListMove(line("$"))<CR>

  " make the buffer count & the buffer numbers available
  " for our other functions
  let b:bufnumbers = l:bufnumbers
  let b:bufcount = l:displayedbufs

  " go to the correct line
  call BufferListMove(l:activebufline)
endfunction

" move the selection bar of the list:
" where can be "up"/"down"/"mouse" or
" a line number
function! BufferListMove(where)
  if b:bufcount < 1
    return
  endif
  let l:newpos = 0
  if !exists('b:lastline')
    let b:lastline = 0
  endif
  setlocal modifiable

  " the mouse was pressed: remember which line
  " and go back to the original location for now
  if a:where == "mouse"
    let l:newpos = line(".")
    call BufferListGoto(b:lastline)
  endif

  " exchange the first char (>) with a space
  call setline(line("."), " ".strpart(getline(line(".")), 1))

  " go where the user want's us to go
  if a:where == "up"
    call BufferListGoto(line(".")-1)
  elseif a:where == "down"
    call BufferListGoto(line(".")+1)
  elseif a:where == "mouse"
    call BufferListGoto(l:newpos)
  else
    call BufferListGoto(a:where)
  endif

  " and mark this line with a >
  call setline(line("."), ">".strpart(getline(line(".")), 1))

  " remember this line, in case the mouse is clicked
  " (which automatically moves the cursor there)
  let b:lastline = line(".")

  setlocal nomodifiable
endfunction

" tries to set the cursor to a line of the buffer list
function! BufferListGoto(line)
  if b:bufcount < 1 | return | endif
  if a:line < 1
    call cursor(1, 1)
  elseif a:line > b:bufcount
    call cursor(b:bufcount, 1)
  else
    call cursor(a:line, 1)
  endif
endfunction

" loads the selected buffer
function! LoadBuffer()
  " get the selected buffer
  let l:result = BufferListGetSelectedBuffer()
  let l:str = l:result['str']
  " kill the buffer list
  bwipeout
  " ...and switch to the buffer number
  exec ":b " . l:str
endfunction

" deletes the selected buffer
function! BufferListDeleteBuffer()
  " get the selected buffer
  let l:result = BufferListGetSelectedBuffer()
  let l:str = l:result['str']
  let l:line = l:result['line']
  " kill the buffer list
  bwipeout
  " delete the selected buffer
  exec ":bdelete " . l:str
  " and reopen the list
  call BufferList()
  call BufferListMove(l:line)
endfunction

function! BufferListGetSelectedBuffer()
  " this is our string containing the buffer numbers in
  " the order of the list (separated by ':')
  let l:str = b:bufnumbers
  let l:line = 1

  " remove all numbers BEFORE the one we want
  let l:i = 1 | while l:i < line(".") | let l:i = l:i + 1
    let l:str = strpart(l:str, stridx(l:str, ':') + 1)
    let l:line = l:line + 1
  endwhile

  " and everything AFTER
  let l:str = strpart(l:str, 0, stridx(l:str, ':'))

  return {'str': l:str, 'line': l:line }
endfunction

