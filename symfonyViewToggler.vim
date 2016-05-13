" TODOS:
"     - AA sollte TypeHint können, dann 
"         /** @var SomeClass */
"         protected $someMember;
"     - Für Funktionen AF anlegen?
"       Da wäre fast ein Mapping besser, um zur function-Zeile springt
"     - GetBaseDir cachen
"     - Bei dispatch.vim ca. in Zeile 850 'normal G' einfügen
:command! -nargs=? PT call SNIPhpUnitToggler()
nmap <leader>se :call ToggleSymfonyView('edit')<cr>
nmap <leader>ss :call ToggleSymfonyView('sp')<cr>
nmap <leader>sv :call ToggleSymfonyView('vs')<cr>
nmap <leader>st :call ToggleSymfonyView('tabnew')<cr>

:command! -nargs=? SS call ShowServiceDefinition("<args>")
autocmd BufEnter * call GetBaseDir()
:command! -nargs=1 G call Grep("<args>")

" Wir wollen mit go ein preview des Treffers sehen
autocmd FileType qf :call InitQfList()

" Folgendes am besten nur bei PHP-Files
nmap <2-LeftMouse> :exe ":call SNIFindFunctionDefinition('" . expand("<cword>") . "', 'e')"<cr>
nmap <leader>fe :exe ":call SNIFindFunctionDefinition('" . expand("<cword>") . "', 'e')"<cr>
nmap <leader>fs :exe ":call SNIFindFunctionDefinition('" . expand("<cword>") . "', 's')"<cr>
nmap <leader>fv :exe ":call SNIFindFunctionDefinition('" . expand("<cword>") . "', 'v')"<cr>
nmap <leader>ft :exe ":call SNIFindFunctionDefinition('" . expand("<cword>") . "', 't')"<cr>

func! GetSymfonyVersion()
    return 2
endfunc

func! AddArgToConstructor(args)
    normal mz
    let parts = split(a:args)
    if len(parts) == 2
        let varName = parts[0]
        let className = parts[1]
    else
        let varName = a:args
        let className =""
    endif
    let varName = substitute(varName, '\$\?', '', '')

    " Erst sehen wir nach, wo die öffnende Klammer von construct ist
    :normal /__constructf(
    let posOfOpeningBracket = getpos(".")[2]
    :normal /constructf)
    let posOfClosingBracket = getpos(".")[2]

    " Neue Variable in der Klammer hinzufügen
    if (posOfClosingBracket - posOfOpeningBracket > 2)
        exec "normal i, "
        normal l
    endif

    if className == ""
        exec "normal i$" . varName
    else
        exec "normal i" . className . ' $' . varName
    endif

    " Neue Variable am Ende von Construct einer protected Variablen übergeben
    exec 'normal /{%O$this->' . varName . ' = $' . varName . ';'

    :normal /__construct
    :normal ?^\s*$

    normal o
    if className != ''
        exec 'normal O/** @var ' . className . ' */'
        normal j
    endif

    exec 'normal Oprotected $' . varName . ';'
    normal mu

    " Damit wir mit <ctrl-o> schnell zur letzten Stelle springen können gehen
    " wir nochmal an den Anfang, dann zurück
    normal 'z
    normal 'u
endfunc


" Gibt das Directory mit dem .git-Dir zurück, falls es existiert.
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

function! Strip(input_string)
    " return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
    return substitute(a:input_string, '\n\+$', '', '')
endfunction

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
    let om = a:openMode
    if om == 's'
        let om = 'split'
    endif
    if om == 'v'
        let om = 'vsplit'
    endif
    if om == 't'
        let om = 'tabe'
    endif

    if filereadable(a:path) == 1 || confirm('File '.a:path.' anlegen?', "n\ny") == 2
        exec(om . ' ' . a:path)
        set cursorline
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
            let g:filePath=GetBaseDir().'/app/Resources/views/'.g:parts[2]
        else
            if match(g:parts[0], 'MEDI') >= 0
                let g:filePath=GetBaseDir().'/src/MEDI/'.substitute(g:parts[0], "^xMEDI", "", "").'/Resources/views/'.g:parts[1].'/'.g:parts[2]
            else
                let g:filePath=GetBaseDir().'/src/'.substitute(g:parts[0], "^x", "", "").'/Resources/views/'.g:parts[1].'/'.g:parts[2]
            endif
        endif
    endif

    if len(g:parts) == 2
        let g:filePath=GetBaseDir().'/src/MEDI/'.substitute(g:parts[0], "^xMEDI", "", "").'/Repository/'.g:parts[1].'Repository.php'
        if filereadable(g:filePath) == 0
            let g:filePath=GetBaseDir().'/src/MEDI/'.substitute(g:parts[0], "^xMEDI", "", "").'/Entity/'.g:parts[1].'.php'
        endif
    endif

    return g:filePath
endfunc

func! GetServiceDefinitionUnderCursor()
    " Strings mit 'Bundle' oder Leerzeichen sind keine Service-Definitionen
    let string = GetQuotedString()
    if string == '' || match(string, '@Bundle') >= 0 || match(string, ' ') >= 0
        return ''
    endif

    " Ein container:debug, aber Antwort ohne Farben. Funktioniert auch für private Services.
    if GetSymfonyVersion() == 2
        let command = "php ".GetBaseDir()."/app/console container:debug ".string.' | sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"'
    else
        let command = "php ".GetBaseDir()."/bin/console debug:container ".string.' | sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"'
    endif
    let logicalPath=system(command)
    let logicalPath=substitute(logicalPath, '.*Class\s*', '', 'v')
    let logicalPath=substitute(logicalPath, "\n.*", '', 'v')

    return TranslateLogicalFilePath(logicalPath)
endfunc

func! TranslateLogicalFilePath(logicalPath)
    let fileName=substitute(a:logicalPath, '.*\\', '', '')
    let command = 'find ' . GetBaseDir() . ' -name ' . Trim(fileName) . '*'
    let filePathes=split(system(command), "\n")
    for filePath in filePathes
        let a = substitute(filePath, '/', '', 'g')
        let b = substitute(a:logicalPath, '\\', '', 'g')
        if match(a, b)
            return filePath
        endif
    endfor
    return ''
endfunc

function! Trim(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

func! Grep(search)
    " grep -r -e 'some pattern' path/* funkttioniert, aber ohne 'Progress'
    let command='vimgrep /\c' . a:search . '/j ' . GetBaseDir() . '/src/**/*.php'
    exec command
    let command='vimgrepadd /\c' . a:search . '/j ' . GetBaseDir() . '/src/**/*.feature'
    exec command
    let command='vimgrepadd /\c' . a:search . '/j ' . GetBaseDir() . '/src/**/*.yml'
    exec command

    if len(getqflist()) > 1
        exec 'copen'
        return
    elseif len(getqflist()) == 1
        exec 'cfirst'
        return
    endif
endfunc

" Die Idee ist, dass wir erst zur Klasse des Services springen,
" und anschließend zur Service-Definition, was hiermit geschieht:
func! ShowServiceDefinition(openMode)
    if a:openMode == ''
        let openMode='e'
    else
        let openMode=a:openMode
    endif

    " Macht aus /irgend/ein/pfad/file.php \pfad\file.php
    let fileNameWithoutEnding = substitute(expand("%:p"), "\\.php$", "", "")
    let fileNameWithoutEnding = substitute(fileNameWithoutEnding, '.*/\([^/]*/[^/]*/[^/]*\)', '\1', '')
    let fileNameWithoutEnding = substitute(fileNameWithoutEnding, '/', '\\\\', 'g')

    let command = 'silent! vimgrep /' . fileNameWithoutEnding . '/j ' . GetBaseDir() . '**/*.yml'
    exec command

    if (len(getqflist()) > 0)
        " Wenn wir mindestens eine Stelle gefunden haben, springen wir zur Ersten.
        " Die nächste Zeile nur damit der openMode berücksichtigt wird.
        call OpenFile($MYVIMRC, a:openMode)
        cfirst
    else
        " Sonst zur services.yml
        let path = substitute(expand("%:p"), "Bundle.*", "Bundle/Resources/config/services.yml", "")
        call OpenFile(path, a:openMode)
    endif
endfunc

func! InitQfList()
    nmap <buffer> go <cr>z<cr>:copen<cr>
endfunc

autocmd! BufEnter *Test.php call InitTestMapping()
func! InitTestMapping()
    if match(expand('%'), 'Test.php')
        :nmap <buffer> <leader>p :call ExecuteUnitTest()<cr>
    endif
endfunc

func! ExecuteUnitTest()
    let @a=GetBaseDir()
    let command='Dispatch php '.@a.'/vendor/phpunit/phpunit/phpunit -c '.@a.'/app/phpunit.xml'
    let command='Dispatch phpunit -c '.@a.'/app/phpunit.xml'
    let command=command .' --filter ' . substitute(expand('%'), '.php', '', '')
    "let command='Dispatch phpunit -c /home/steffen/Projekte/mediVerbund/medios/app/phpunit.xml --filter Quartal'
    exec command
"normal <c-w>k
endfunc

func! SNIGetPathesWithTag(tagName)
    let tagPath = SNIGetTagPath()
    if tagPath == ''
        echo 'Kein tag-File gefunden'
        return
    endif

    let command = "awk '/^" . a:tagName . "/ {print $2}' " . tagPath
    let filePathesString = system(command)
    return split(system(command), "\n")
endfunc

func! SNIStripSlashes(text)
    let result = substitute(a:text, '\\', '', 'g')
    return substitute(result, '/', '', 'g')
endfunc

func! SNIStripDotPhp(text)
    return substitute(a:text, '.php$', '', '')
endfunc

func! SNIGetTagPath()
    let path = GetBaseDir() . '/tags'
    if filereadable(path)
        return path
    endif
    return ''
endfunc

func! SNIGetStringsWithBackslash()
    return SNIGetStringsWithPattern('\m\w\+\\[a-zA-Z0-9_\\]\+')
endfunc

func! SNIGetStringsWithPattern(pattern)
    let startPos = getpos(".")
    let hits = []

    normal gg
    let command='%s/' . a:pattern . '/\=len(add(hits, submatch(0))) ? submatch(0) : ""/ge'
    silent execute command

    call setpos('.', startPos)
    return hits
endfunc

func! SNIFindFunctionDefinition(funcName, openMode)
    " Wir holen uns aus dem Tagfile die Pfade von Files mit der Funktion
    " und (unter anderem) alle use-Pfade oder Type-Hint-Pfade,
    " genauer alles was wie ..\..\.. aussieht, aber auch z.B.
    " MEDIVertragBundle\..
    let pathesWithTag = SNIGetPathesWithTag(a:funcName)

    if len(pathesWithTag) == 1
        call OpenFile(GetBaseDir() . '/' . pathesWithTag[0], a:openMode)
        return
    endif
    if len(pathesWithTag) == 0
        echo "Funktion nicht im Tag-File gefunden"
        return
    endif

    let possiblePathes = SNIGetStringsWithBackslash()

    " Wegen z.B. MEDIVertragBundle nehmen wir alle Slashes raus
    let normalizedPossiblePathes = []
    for i in range(0, len(possiblePathes) - 1)
        call add(normalizedPossiblePathes, SNIStripSlashes(possiblePathes[i]))
    endfor

    " Wir erstellen ein Result mit den Matches
    let result = []
    for pathWithTag in pathesWithTag
        let fullNormalizedPath = SNIStripDotPhp(SNIStripSlashes(pathWithTag))
        for normalizedPossiblePath in normalizedPossiblePathes
            if match(fullNormalizedPath, normalizedPossiblePath) != -1 
                call add(result, pathWithTag)
            endif
        endfor
    endfor

    if len(result) == 1
        call OpenFile(GetBaseDir() . '/' . result[0], a:openMode)
        silent call search(a:funcName)
    else
        write
        call OpenFile(expand('%:p'), a:openMode)
        exec('tselect ' . a:funcName)
    endif
endfunc

" Wollen bequem zwischen Test- und Original-File toggeln können 
func! SNIPhpUnitToggler()
    let testDir = SNIFindTestDir()
    if testDir == ''
        echo "Kein Test-Dir gefunden"
        return
    endif

    if match(SNIGetCurrentDir(), testDir) != -1 
        " Wir sind im Test-File
        silent only
        let originalFilePath = substitute(expand("%:p"), 'Test.php', '.php', '')
        for testDirName in ['test', 'tests', 'Test', 'Tests']
            let originalFilePath = substitute(originalFilePath, '/' . testDirName . '/', '/', '')
        endfor
        if filereadable(originalFilePath)
            exec ":split " . originalFilePath
            exe "normal \<c-w>J"
        else
            echo "File " . originalFilePath . " konnte nicht geöffnet werden."
        endif
    else
        " Wir sind im original-File
        let beforeTestDir = substitute(testDir, "/[^/]*$", "", "")
        let restPath = substitute(expand("%:p"), beforeTestDir, '', '')
        let testPath = substitute(testDir . restPath, '.php$', 'Test.php', '')

        " Schon mal den richtigen Pfad öffnen
        only
        split
        execute "edit " . testPath

        " Wenn das Test-File noch nicht existiert hat, schreiben wir was rein
        if (glob(testPath) == '')
            let namespace = substitute(testPath, '^.*/\(.\{-}\/.\{-}Bundle\)', '\1', '')
            let namespace = substitute(namespace, '.php$', '', '')

            let g:puOriginalFileUsageStatement = 'use ' . namespace
            let g:puOriginalFileNamespaceStatement = 'namespace ' . substitute(namespace, 'Bundle/', 'Bundle/Tests/', '') 
            let g:puOriginalFileNamespaceStatement = substitute(g:puOriginalFileNamespaceStatement, '\(.*\)/.*', '\1', '')
            let g:puOriginalFileUsageStatement = substitute(g:puOriginalFileUsageStatement, '/', '\\\', 'g')
            let g:puOriginalFileNamespaceStatement = substitute(g:puOriginalFileNamespaceStatement, '/', '\\\', 'g')

            exec "normal iphpunittest1\<c-j>"
        endif
    endif
endfunc

" Vom BaseDir bis zum aktuellen Directory laufen wir alle Pfade durch
" und suchen nach Directories mit Namen .../test, .../Test, etc.
" Wenn nichts gefunden wird geben wir '' zurück.
func! SNIFindTestDir()
    let currentDir = SNIGetCurrentDir()
    let baseDir = GetBaseDir()
    if baseDir == ''
        return ''
    endif

    let subDirsString = substitute(currentDir, baseDir, "", "")
    let subDirs = split(subDirsString, '/')
    let loopDir = baseDir

    for subDir in subDirs
        for testDirName in ['test', 'tests', 'Test', 'Tests']
            let dirToCheck = loopDir . '/' . testDirName
            if SNIIsDir(dirToCheck)
                return dirToCheck
            endif
        endfor
        let loopDir .= '/' . subDir
    endfor
endfunc

func! SNIGetCurrentDir()
    let path = expand("%:p")
    let currentDir = substitute(path, "/[^/]*$", "", "")

    return currentDir
endfunc

func! SNIIsDir(path)
    return (filewritable(a:path) == 2)
endfunc
