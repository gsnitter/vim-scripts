nmap <leader>se :call ToggleSymfonyView('edit')<cr>
nmap <leader>ssp :call ToggleSymfonyView('sp')<cr>
nmap <leader>svs :call ToggleSymfonyView('vs')<cr>
nmap <leader>st :call ToggleSymfonyView('tabnew')<cr>

" Gibt das Directory mit dem .git-Dir zurück, falls es existiert.
func! GetBaseDir()
    let result=system('git rev-parse --show-toplevel')
    if v:shell_error != ''
        let result=""
    else
        let result=Strip(result)."/"
    endif
    let @a=result
    return result
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
    let g:filePath = GetFilePathFromSymfonyString(GetPathUnderCursor())

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
    return g:filePath
endfunc

