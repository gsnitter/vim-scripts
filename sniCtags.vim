" Hiermit wird das tags-File beim jeden Speichern aktualisiert.
"
" Ab besten folgendes in ~/.ctags
" --exclude=app/cache/*
" --exclude=app/logs/*
" --exclude=vendor/*/tests/*
" --exclude=*.js
" --exclude=web/*
" --extra=+f
" --langdef=file
" --langmap=file:.html.twig.xml.yml

function! GetDelTagOfFileCommand(file)
    let tagFilePath = GetTagFilePath()
    let f = substitute(a:file, GetBaseDir(), "", "")
    let f = escape(f, './')
    let cmd = 'sed -i "/' . f . '/d" "' . tagFilePath . '"'
    return cmd
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
    let file = expand("%:p")

    let cmd = GetDelTagOfFileCommand(file) . ' && ctags -a -f '.tagFilePath.' "'.file.'" &'
    call system(cmd)
endfunction

if exists('g:loaded_sni_ctags')
    finish
endif
let g:loaded_sni_ctags = 1
autocmd BufWritePost *.php,*.js,*.twig call UpdateTags()
