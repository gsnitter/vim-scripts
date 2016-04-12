nmap <leader>se :call ToggleSymfonyView('edit')<cr>
nmap <leader>ss :call ToggleSymfonyView('sp')<cr>
nmap <leader>sv :call ToggleSymfonyView('vs')<cr>
nmap <leader>st :call ToggleSymfonyView('tabnew')<cr>
" Wollen noch Service-Namen auflösen, aber erst die tag-Files splitten.
" Dazu http://vim.wikia.com/wiki/Autocmd_to_update_ctags_file versuchen.

" Sprung von Repository zu Enity,
" von Controller zu FormType
" oder von View zu Controller.
" nmap <leader>sr :call TogglePartnerFiles()<cr>

" Gibt das Directory mit dem .git-Dir zurück, falls es existiert.
func! GetBaseDir()
    let dir = getcwd()
    let baseDir = ''

    while dir <> ''
        if isdirectory(dir . '/.git')
            let baseDir = dir
        endif
        let dir = substitute(dir, '/[^/]*$', '', '')
    endwhile

    return baseDir

    " let result=system('git rev-parse --show-toplevel')
    " if v:shell_error != ''
        " let result=""
    " else
        " let result=Strip(result)."/"
    " endif
    " let @a=result
    " return result
endfunc
function! Strip(input_string)
    " return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
    return substitute(a:input_string, '\n\+$', '', '')
endfunction
autocmd BufEnter * call GetBaseDir()

" se, svs, ssp, st
func! ToggleSymfonyView(openMode)
    let l:symfonyPath = GetSymfonyPath()
    if l:symfonyPath == ''
        echo "Kein Symfony-Pfad gefunden"
    else
        call OpenFile(l:symfonyPath, a:openMode)
    endif
endfunc

func! OpenFile(path, openMode)
    if filereadable(a:path) == 1 || confirm('File '.a:path.' anlegen?', "n\ny") == 2
        exec(a:openMode.' '.a:path)
    endif
endfunc

" Sucht in einem Controller sowas wie ein ..:..:..-String
" und gibt den zugehörigen Pfad zum Template zurück
func! GetSymfonyPath()
    let startPos = getpos(".")

    let g:filePath = GetFilePathForRepositoryLine()
    if g:filePath == ''
        let g:filePath = GetFilePathFromSymfonyString(GetPathUnderCursor())
    endif

    if g:filePath == ''
        call setpos('.', startPos)
        let g:filePath = GetServiceDefinitionUnderCursor()
    endif

    " Wenn der Cursor nicht auf einer Zeile mit einem String wie ..:..:.. war
    if g:filePath == ''
        call setpos('.', startPos)
        call GoToFunctionDefinition()
        normal k
        " Suche die erste vorangehende Zeile, die nicht mit einem Stern beginnt
        call search('^\s*[^\* ]', 'b')
        " Von da suchen wir die nächste Zeile mit @Template
        let templateLineNr=search('@Template')

        if templateLineNr>0
            " Jetzt von urspr. Position aus z.B. Ende der Funktion suchen
            call setpos('.', startPos)
            call search('^\s*}\s*$')
            call search('@Template', 'b')
            if getpos('.')[1]==templateLineNr
                let templateLine=getline(templateLineNr)
                if match(templateLine, '@Template') >= 0
                    " @Template-Zeile existiert. Ist da was angegeben?
                    if match(templateLine, ':') >= 0
                        let g:filePath = GetFilePathFromSymfonyString(GetPathUnderCursor())
                    else
                        " let bundleName = substitute(matchstr(expand('%:p'), '\w*Bundle'), 'Bundle', '', '')
                        let bundleName = matchstr(expand('%:p'), '\w*Bundle')
                        let controllerName = substitute(expand('%'), 'Controller.php', '', '')
                        let actionName = substitute(GetFunctionNameUnderCursor(), 'Action', '', '')
                        let symfonyString = 'MEDI'.bundleName.':'.controllerName.':'.actionName.'.html.twig'
                        let g:filePath = GetFilePathFromSymfonyString(symfonyString)
                    endif
                endif
            endif
        endif
    endif
    call setpos('.', startPos)

    " Keine @Template-Angabe und auch nichts unter dem Cursor.
    " Jetzt durchsuchen wir die Funktion nach einem ..:..:..-String.
    if g:filePath == ''
        call GoToFunctionDefinition()
        call search("{")
        let l:functionStart = line(".")
        normal %
        call search('\w*:\w*:\w*', "b")
        if line(".")>l:functionStart
            let g:filePath = GetFilePathFromSymfonyString(GetPathUnderCursor())
        endif
        call setpos('.', startPos)
    endif
    
    return g:filePath
endfunc

func! GetFilePathForRepositoryLine()
    if match(getline("."), "getRepository") >= 0
        let l:path = GetPathUnderCursor()
        echo l:path
        return
    endif
endfunc

func! GoToFunctionDefinition()
    call search('^\s*}\s*$')
    call search(' function ', 'b')
endfunc

func! GetFunctionNameUnderCursor()
    let startPos = getpos(".")
    call GoToFunctionDefinition()
    exe 'normal wwvt("yy'
    call setpos('.', startPos)
    return @y
endfunc

" Wenn der Cursor auf einem String der Bauart MyBundle:Bla:blupp.html.twig
" steht, wird der FilePath dafür zurückgegeben.
func! GetPathUnderCursor()
    " Wollen "MEDIArztBundle:Arzt:index.html.twig" kopieren
    let startPos = getpos(".")
    normal 0f:
    " Erstes Zeichen rückwärts suchen, dass kein \w oder : ist.
    call search('[^a-zA-Z0-9:\.]', 'b')
    normal l
    " Position merken
    normal v
    " Letztes Zeichen suchen, dass kein \w oder : ist.
    call search('[^a-zA-Z0-9:\.]')
    normal h
    exe 'normal "yy'
    " Jetzt zurück zum Start
    return @y
    call setpos('.', startPos)
endfunc

func! GetQuotedString()
    let startPos = getpos(".")
    normal 0
    call search("['\"]")
    if line(".") == startPos[1]
        normal lv
        let stringStartPos = getpos(".")[2]
        call search("['\"]")
        if line(".") == startPos[1] && stringStartPos < getpos(".")[2]
            normal h"zy
            call setpos('.', startPos)
            return @z
        endif
    endif

    call setpos('.', startPos)
    return ''
endfunc

func! GetFilePathFromSymfonyString(str)
    let g:parts=split('x'.a:str, ':')
    let g:filePath = ''
    if len(g:parts) == 3
        if g:parts[0] == 'x'
            let g:filePath=@a.'app/Resources/views/'.g:parts[2]
        else
            let g:filePath=@a.'src/MEDI/'.substitute(g:parts[0], "^xMEDI", "", "").'/Resources/views/'.g:parts[1].'/'.g:parts[2]
        endif
    endif

    if len(g:parts) == 2
        let g:filePath=@a.'src/MEDI/'.substitute(g:parts[0], "^xMEDI", "", "").'/Repository/'.g:parts[1].'Repository.php'
        if filereadable(g:filePath) == 0
            let g:filePath=@a.'src/MEDI/'.substitute(g:parts[0], "^xMEDI", "", "").'/Entity/'.g:parts[1].'.php'
        endif
    endif

    return g:filePath
endfunc

func! GetServiceDefinitionUnderCursor()
    " Strings mit 'Bundle' oder Leerzeichen sind keine Service-Definitionen
    let string = GetQuotedString()
    if match(string, '@Bundle') >= 0 || match(string, ' ') >= 0
        return ''
    endif

    " Ein container:debug, aber Antwort ohne Farben. Funktioniert auch für private Services.
    let command = "php ".@a."app/console container:debug ".string.' | sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"'
    let logicalPath=system(command)
    let logicalPath=substitute(logicalPath, '.*Class\s*', '', 'v')
    let logicalPath=substitute(logicalPath, "\n.*", '', 'v')

    return TranslateLogicalFilePath(logicalPath)
endfunc

func! TranslateLogicalFilePath(logicalPath)
    let fileName=substitute(a:logicalPath, '.*\\', '', '')
    let filePathes=split(system('find ' . @a . ' -name ' . fileName . '*'), "\n")
    for filePath in filePathes
        let a = substitute(filePath, '/', '', 'g')
        let b = substitute(a:logicalPath, '\\', '', 'g')
        if match(a, b)
            return filePath
        endif
    endfor
    return ''
endfunc

" G someFunction soll nur in den eigenen PHP-Files suchen
:command! -nargs=1 G call Grep("<args>")
func! Grep(search)
    let command='vimgrep /\c' . a:search . '/j ' . GetBaseDir() . '/src/**/*.php'
    exec command

    if len(getqflist()) > 1
        exec 'copen'
        return
    elseif len(getqflist()) == 1
        exec 'cfirst'
        return
    endif
endfunc

:command! -nargs=? SS call ShowServiceDefinition("<args>")
func! ShowServiceDefinition(openMode)
    if a:openMode == ''
        let openMode='e'
    else
        let openMode=a:openMode
    endif
    let fileNameWithoutEnding = substitute(expand("%"), "\\..*", "", "")

    let path = expand("%:p")
    let path = substitute(path, "Bundle.*", "Bundle/Resources/config/services.yml", "")
    call OpenFile(path, openMode)

    call search(fileNameWithoutEnding)
endfunc
