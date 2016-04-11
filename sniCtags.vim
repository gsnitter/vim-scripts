" Ab besten folgendes in ~/.ctags
" --exclude=app/cache/*
" --exclude=app/logs/*
" --exclude=vendor/*/tests/*
" --exclude=*.js
" --exclude=web/*
" --extra=+f
" --langdef=file
" --langmap=file:.html.twig.xml.yml

function! DelTagOfFile(file)
  let fullpath = a:file
  let cwd = getcwd()
  let tagFilePath = GetTagFilePath()
  let f = substitute(fullpath, cwd . "/", "", "")
  let f = escape(f, './')
  let cmd = 'sed -i "/' . f . '/d" "' . tagFilePath . '"'
  let resp = system(cmd .' &')
endfunction

function! GetTagFilePath()
  let tagFilePath = GetBaseDir() . "/tags"
  if file_readable(tagFilePath) == 0
      return ''
  endif
  return tagFilePath
endfunc

function! UpdateTags()
  let tagFilePath = GetTagFilePath()
  if tagFilePath == ''
      return
  endif
  let f = expand("%:p")
  call DelTagOfFile(f)

  let cmd = 'ctags -a -f '.tagFilePath.' "'.f.'" &'
  call system(cmd)
endfunction
autocmd BufWritePost *.php,*.js,*.twig call UpdateTags()

