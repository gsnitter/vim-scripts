:command! -nargs=0 DB call SNIInsertDocBlock()
let s:path = expand('<sfile>:p:h')
func! SNIInsertDocBlock()
    let functionDefinitionStartLineNumber = line('.')
    call search('{')
    let functionBodyStartLineNumber = line('.')
    normal %
    let functionBodyEndLineNumber = line('.')
    normal %
    call search(')', 'b')
    let functionDefinitionEndLineNumber = line('.')

    call search('*/', 'b')
    let docBlockEndLineNumber = line('.')
    if (docBlockEndLineNumber + 2 >= functionDefinitionStartLineNumber && docBlockEndLineNumber < functionDefinitionEndLineNumber)
        call search('/\*\*', 'b')
        let docBlockStartLineNumber = line('.')
        let deleteOldDocBlockCommand=docBlockStartLineNumber . ',' . docBlockEndLineNumber . 'd'
        call search('function')
    else
        let docBlockEndLineNumber = 0
        let docBlockStartLineNumber = 0
    endif

    " Aufruf des PHP-Scripts samt Parametern bauen
    let com = '!php ' . s:path . '/sniInsertDocBlock.php'
    let com = com . ' ' . docBlockStartLineNumber
    let com = com . ' ' . docBlockEndLineNumber
    let com = com . ' ' . functionDefinitionStartLineNumber
    let com = com . ' ' . functionDefinitionEndLineNumber
    let com = com . ' ' . functionBodyStartLineNumber
    let com = com . ' ' . functionBodyEndLineNumber
    "let com = com . ' ' . substitute(shellescape(join(getline(1, line('$')), "\n")), '!', '', '')
    let com = com . ' ' . substitute(shellescape(join(getline(1, line('$')), "\n")), '\!', '', 'g')

    " Alten DocBlock löschen, falls vorhanden
    if (docBlockStartLineNumber > 0)
        exec deleteOldDocBlockCommand
    else
        exec functionDefinitionStartLineNumber
    endif

    :normal k
    exec 'silent read ' . com
endfunc
