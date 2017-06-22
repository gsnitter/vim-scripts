" Für jedes File wollen wir wissen, wo ein
autocmd BufEnter * call GetBaseDir()

func! GetBaseDir()
    let dir = getcwd()

    " Wenn das baseDirectory noch passt servieren wir den Cache
    if match(expand('%:p'), @a) > 0
        return @a
    endif

    let baseDir = ''

    while dir != ''
        if isdirectory(dir . '/.git')
            let baseDir = dir
        endif
        let dir = substitute(dir, '/[^/]*$', '', '')
    endwhile
    let @a=baseDir

    return baseDir
endfunc
