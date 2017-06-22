<?php

class CodeBlock
{
    public $lines = [];
    public static $keyPartCount = 1;

    /**
     * Constructor.
     *
     * @param string $line
     */
    public function __construct(string $line)
    {
        $this->lines = [$this->trimWhitespace($line)];
    }

    /**
     * Fügt eine Codezeile hinzu.
     *
     * @param string $line Eine Zeile
     *
     * @return $this
     */
    public function addLine(string $line): CodeBlock
    {
        $this->lines[] = $this->trimWhitespace($line);
        return $this;
    }

    /**
     * @param mixed $line
     */
    protected function trimWhitespace($line)
    {
        if (preg_match('@^\s*/\*\*@', $line)) {
            return trim($line);
        } else {
            return ' ' . trim($line);
        }
    }

    /**
     * @return string
     */
    public function __toString(): string
    {
        return implode("\n", $this->lines);
    }

    /**
     * @return bool
     */
    public function isGroupable(): bool
    {
        return false;
    }

    /**
     * Gibt die einzelnen Teile der ersten Zeile zurück.
     *
     * Gibt z.B. sowas wie ['@param', 'string', '$text', 'Die Beschreibung'], wenn
     * keyPartCount 4 wäre.
     *
     * @return array
     */
    public function getKeyParts(): array
    {
        $line = preg_replace('@^\s*\*\s*@', '', $this->lines[0]);
        return preg_split('@\s+@', $line, self::$keyPartCount);
    }

    /**
     * @return string
     */
    protected function getLastLine(): string
    {
        return $this->lines[count($this->lines) - 1];
    }

    /**
     * @return $this
     */
    public function removeLastBlankLine(): CodeBlock
    {
        if (preg_match('@^\s*\*\s*$@', $this->getLastLine())) {
            array_pop($this->lines);
        }

        return $this;
    }
}

class BlankLine extends CodeBlock
{
}

class Annotation extends CodeBlock
{
    public $annotation;
}

class ParamAnnotation extends Annotation
{
    public $varName;
    public $typeHint;
    public static $keyPartCount = 4;

    /**
     * Constructor.
     *
     * @param string $line
     */
    public function __construct(string $line)
    {
        parent::__construct($line);
        preg_match('/^\s*\*\s*@param\s+(\w+)\s+(.\w+)/', $line, $matches);
        $this->typeHint = $matches[1];
        $this->varName = $matches[2];
    }

    /**
     * @param Param $param
     *
     * @return ParamAnnotation
     */
    public function createByParam(Param $param): ParamAnnotation
    {
        return new ParamAnnotation(" * @param {$param->getTypeHint()} {$param->getVarName()}");
    }

    /**
     * @return bool
     */
    public function isGroupable(): bool
    {
        return true;
    }

    /**
     * @return string
     */
    public function getGroupName(): string
    {
        return 'ParamAnnotations';
    }

    /**
     * Gibt die einzelnen Teile der ersten Zeile zurück.
     *
     * Gibt z.B. sowas wie ['@param', 'string', '$text', 'Die Beschreibung'], wenn
     * keyPartCount 4 wäre.
     *
     * @return array
     */
    public function getKeyParts(): array
    {
        $line = preg_replace('@^\s*\*\s*@', '', $this->lines[0]);
        // TODO SNI
        return preg_split('@\s+@', $line, self::$keyPartCount);
    }
}

class ReturnAnnotation extends Annotation
{
    public $typeHint;

    /**
     * Constructor.
     *
     * @param string $line
     */
    public function __construct(string $line)
    {
        parent::__construct($line);
        preg_match('/^\s*\*\s*@return\s+(.?\w+)/', $line, $matches);
        $this->typeHint = $matches[1];
    }

    /**
     * @param string $newTypeHint
     *
     * @return $this
     */
    public function updateTypeHint(string $newTypeHint): Annotation
    {
        $this->lines[0] = preg_replace('|^\s*\*\s*@return\s+.?\w+|', " * @return {$newTypeHint}", $this->lines[0]);
        $this->typeHint = $newTypeHint;

        return $this;
    }
}

class ThrowsAnnotation extends Annotation
{
    public $exceptionName;

    /**
     * Constructor.
     *
     * @param string $line
     */
    public function __construct(string $line)
    {
        parent::__construct($line);
        preg_match('/^\s*\*\s*@throws\s+(.?\w+)/', $line, $matches);
        $this->exceptionName = $matches[1];
    }

    /**
     * @param ThrowsAnnotation $anno
     *
     * @return bool
     */
    public function describesSameAs(ThrowsAnnotation $anno): bool
    {
        return true;
    }

    /**
     * @param ThrowsAnnotation $anno
     *
     * @return $this
     */
    public function updateBy(ThrowsAnnotation $anno): ThrowsAnnotation
    {
        // str_replace hat leider keinen vierten Parameter für die Maximalzahl
        // der Ersetzungen
        $this->lines[0] = preg_replace('|@throws\s+(\w+)|', "@throws {$anno->exceptionName}", $this->lines[0]);
        return $this;
    }
}

/**
 * Klasse, um den eigentlichen DocBlock zu bauen
 *
 * Nimmt einzelne Zeilen von einem alten DocBlock entgegen und legt das intern
 * als CodeBlock-Objekte an.
 */
class DBBuilder
{
    protected $lastCodeBlock;
    protected $codeBlocks = [];

    /** @var CodeBlockModifier[] */
    protected $codeBlockModifiers = [];

    /**
     * @param string $line
     *
     * @return $this
     */
    public function addToCodeBlocks(string $line): DBBuilder
    {
        $type = null;
        $annotationFound = array_reduce($this->codeBlocks, function($hasAnnotation, $codeBlock) {
            return $hasAnnotation || $codeBlock instanceof Annotation;
        });;

        if (!$this->lastCodeBlock) {
            $type = 'CodeBlock';
        }

        /**
         * Bei @bla-Annotation ein neues Objekt der Klasse BlaAnnotation,
         * falls das existiert, sonst nur ein Annotation-Objekt.
         */
        if (preg_match('/^\s*\*\s*@(\w+)\s+(.\w+)/', $line, $matches)) {
            if (!$annotationFound) {
                $this->lastCodeBlock->removeLastBlankLine();
            }
            $annotationFound = true;
            $anno = $matches[1];
            $className = ucfirst($anno) . 'Annotation';
            $type = class_exists($className) ? $className : 'Annotation';
        }

        // Leerzeilen behandeln wir besonders, ausser vor den ersten Annotations
        if ($annotationFound && preg_match('/^\s*\*\s*$/', $line)) {
            $type = 'BlankLine';
        }

        if (strpos($line, '*/') !== false) {
            $type = 'CodeBlock';
        }

        if ($type) {
            $this->lastCodeBlock = new $type($line);
            $this->codeBlocks[] = $this->lastCodeBlock;
        } else {
            $this->lastCodeBlock->addLine($line);
        }

        return $this;
    }

    /**
     * @param array $params
     *
     * @return $this
     */
    public function setParams(array $params): DBBuilder
    {
        $newCodeBlocks = [];
        foreach ($params as $param) {
            $matchFound = false;
            foreach($this->codeBlocks as $codeBlock) {
                if ($codeBlock instanceof ParamAnnotation && $codeBlock->varName == $param->getVarName()) {
                    $matchFound = true;
                    $codeBlock->lines[0] = preg_replace(
                        "/{$codeBlock->typeHint} /",
                        "{$param->getTypeHint()} ",
                        $codeBlock->lines[0]
                    );
                    $newCodeBlocks[] = $codeBlock;
                }
            }

            if (!$matchFound) {
                $newCodeBlocks[] = ParamAnnotation::createByParam($param);
            }
        }

        $this->replaceAnnotations($newCodeBlocks, ParamAnnotation::class);
        
        return $this;
    }

    /**
     * @param string $typeHint
     *
     * @return $this
     */
    public function setReturnTypeHint(string $typeHint): DBBuilder
    {
        if (!$typeHint) {
            return $this;
        }

        $matchFound = false;
        
        foreach ($this->codeBlocks as $codeBlock) {
            if ($codeBlock instanceof ReturnAnnotation) {
                $matchFound = true;
                $codeBlock->lines[0] = preg_replace('|^(.*@return\s+)(\w+)|', "$1{$typeHint}", $codeBlock->lines[0]);
                
            }
        }

        if (!$matchFound) {
            $line = " * @return {$typeHint}";
            $anno = new ReturnAnnotation($line);
            array_splice($this->codeBlocks, count($this->codeBlocks) - 1, 0, [$anno]);
        }

        return $this;
    }

    /**
     * @param array $newCodeBlocks
     *
     * @return $this
     */
    protected function replaceParamBlocks(array $newCodeBlocks): DBBuilder
    {
        $firstParamIndex = $lastParamIndex = $firstAnnotationIndex = null;

        foreach ($this->codeBlocks as $index => $codeBlock) {
            if ($codeBlock instanceof ParamAnnotation) {
                $lastParamIndex = $index;
                if ($firstParamIndex === null) {
                    $firstParamIndex = $index;
                }
            }
            if ($firstAnnotationIndex === null && $codeBlock instanceof Annotation) {
                $firstAnnotationIndex = $index;
            }
        }

        $replaceIndex = $firstParamIndex ? : $firstAnnotationIndex;
        $replaceIndex = $replaceIndex ? : count($this->codeBlocks) - 1;

        $linesToReplace = $lastParamIndex ? $lastParamIndex - $firstParamIndex + 1 :  0;
        array_splice($this->codeBlocks, $replaceIndex, $linesToReplace, $newCodeBlocks);

        return $this;
    }

    /**
     * @return array
     */
    public function getCodeBlocks(): array
    {
        return $this->codeBlocks;
    }

    /**
     * @param string $indent
     *
     * @return string
     */
    public function getDocBlock(string $indent = ''): string
    {
        $string = implode("\n", $this->codeBlocks);
        return $indent . str_replace("\n", "\n{$indent}", $string);
    }

    /**
     * Setzt bzw. ersetzt ThrowsAnnotations
     *
     * Die CodeBlocks können sich selbst updaten, auch wo sie eingefügt werden:
     * Dort wo die alten Annotations dieser Art waren, sonst vor die return-
     * Annotation, oder wenn es diese nicht gibt, an dern Schluss.
     * Indem wir die neuen ThrowsAnnotations nach den ParamAnnotations setzen,
     * kommen die also auch in der richtigen Riehenfolge, es sei denn, sie
     * waren in der alten Annotation schon in ungewohnter Reihenfolge.
     *
     * @param array $newAnnotations
     *
     * @return $this
     */
    public function setThrowsAnnotations(array $newAnnotations): DBBuilder
    {
        $className = ThrowsAnnotation::class;

        $this->setTypeAnnotations($className, $newAnnotations);
        return $this;
    }

    /**
     * @param string $className
     * @param array  $newAnnotations
     *
     * @return $this
     */
    protected function setTypeAnnotations(string $className, array $newAnnotations): DBBuilder
    {
        $newCodeBlocks = [];
        $oldAnnotationIndexesUsedAsMatches = [];
        foreach ($newAnnotations as $newAnnotation) {
            $matchFound = false;
            foreach($this->codeBlocks as $index => $oldAnnotation) {
                if (in_array($index, $oldAnnotationIndexesUsedAsMatches)) {
                    continue;
                }

                if (get_class($oldAnnotation) == $className && $oldAnnotation->describesSameAs($newAnnotation)) {
                    $matchFound = true;
                    $oldAnnotationIndexesUsedAsMatches[] = $index;
                    $newCodeBlocks[] = $oldAnnotation->updateBy($newAnnotation);
                    break;
                }
            }

            if (!$matchFound) {
                $newCodeBlocks[] = $newAnnotation;
            }
        }

        $this->replaceAnnotations($newCodeBlocks, $className);
        return $this;
    }

    /**
     * @param array  $newAnnotations
     * @param string $className
     *
     * @return $this
     */
    protected function replaceAnnotations(array $newAnnotations, string $className): DBBuilder
    {
        $firstAnnotationIndex = $lastAnnotationIndex = $returnAnnotationIndex = null;

        foreach ($this->codeBlocks as $index => $codeBlock) {
            if ($codeBlock instanceof $className) {
                $lastAnnotationIndex = $index;
                if ($firstAnnotationIndex === null) {
                    $firstAnnotationIndex = $index;
                }
            }
            if ($codeBlock instanceof ReturnAnnotation) {
                $returnAnnotationIndex = $index;
            }
        }

        $replaceIndex = $firstAnnotationIndex ? : $returnAnnotationIndex;

        // Alte Annotations entfernen
        $this->codeBlocks = array_filter($this->codeBlocks, function($codeBlock) use ($className) {
            return (get_class($codeBlock) != $className);
        });

        $replaceIndex = $replaceIndex ? : count($this->codeBlocks) - 1;

        // $linesToReplace = $lastAnnotationIndex ? $lastAnnotationIndex - $firstAnnotationIndex + 1 :  0;
        array_splice($this->codeBlocks, $replaceIndex, 0, $newAnnotations);
        return $this;
    }

    /**
     * @param CodeBlockModifier $modifier
     *
     * @return $this
     */
    public function applyModifier(CodeBlockModifier $modifier): DBBuilder
    {
        $this->codeBlocks = $modifier->modifyCodeBlocks($this->codeBlocks);
        return $this;
    }
}

interface CodeBlockModifier
{
    /**
     * @param array $codeBlocks
     *
     * @return array
     */
    public function modifyCodeBlocks(array $codeBlocks): array;
}

/**
 * Bei Symfony scheint standardmäßig die throws-Annotation zum Schluss zu kommen.
 */
class ThrowsAnnotationLastModifier implements CodeBlockModifier
{
    /**
     * @inheritDoc
     */
    public function modifyCodeBlocks(array $codeBlocks): array
    {
        $throwsAnnotations = array_filter($codeBlocks, function($codeBlock) {
            return $codeBlock instanceof ThrowsAnnotation;
        });
        $codeBlocks = array_filter($codeBlocks, function($codeBlock) {
            return !$codeBlock instanceof ThrowsAnnotation;
        });

        array_splice($codeBlocks, count($codeBlocks) - 1, 0, $throwsAnnotations);
        return $codeBlocks;
    }
}

/**
 * Gleiche Annotations zusammenfassen und in Spalten übereinander.
 *
 * Z.B. statt param string $something Ein String
 *            param array $somethingDifferent
 * folgende:  param string $something          Ein String
 *            param array  $somethingDifferent
 */
class GroupAndColumizeModifier implements CodeBlockModifier
{
    /**
     * @inheritDoc
     */
    public function modifyCodeBlocks(array $codeBlocks): array
    {
        $groups = [];

        // Gruppen bilden (AfterStart, ParamAnnotation, AfterParamAnnotation, ...)
        $currentGroup = 'Start';
        foreach ($codeBlocks as $codeBlock) {
            if ($codeBlock->isGroupable()) {
                $groupName = $codeBlock->getGroupName();
                $currentGroup = $groupName;
                $groups[$groupName][] = $codeBlock;
            } else {
                $groups['After' . $currentGroup][] = $codeBlock;
            }
        }

        // Haben sowas wie @param Gruke $gurke Eine Gurke, müssen da erstmal die Längen bestimmen
        $maxWordLength = [];
        foreach ($groups as $groupName => $group) {
            foreach ($group as $groupCodeBlock) {
                $keyParts = $groupCodeBlock->getKeyParts();
                foreach ($keyParts as $wordIndex => $word) {
                    $oldVal = isset($maxWordLength[$groupName][$wordIndex])? $maxWordLength[$groupName][$wordIndex] : 0;
                    $maxWordLength[$groupName][$wordIndex] = max($oldVal, strlen($word));
                }
            }
        }

        // Die Stringlängen in den Gruppen ersetzen
        foreach ($groups as $groupName => $group) {
            foreach ($group as $groupCodeBlock) {
                if (count($maxWordLength[$groupName]) > 1) {
                    $firstLine  = ' * ';
                    $keyParts = $groupCodeBlock->getKeyParts();
                    foreach ($keyParts as $wordIndex => $word) {
                        $wantedLength = $maxWordLength[$groupName][$wordIndex] + 1;
                        $firstLine .= str_pad($word, $wantedLength);
                    }
                    $groupCodeBlock->lines[0] = rtrim($firstLine);
                }
            }
        }

        return $codeBlocks;
    }
}

class SpecialReturnTypeModifier implements CodeBlockModifier
{
    protected $lines = [];

    /**
     * Constructor.
     *
     * @param array $functionBodyLines
     */
    public function __construct(array $functionBodyLines)
    {
        $this->lines = $functionBodyLines;
    }

    /**
     * @inheritDoc
     */
    public function modifyCodeBlocks(array $codeBlocks): array
    {
        $returnExpressions = [];
        foreach ($this->lines as $line) {
            if (preg_match('/return\s+(.?\w+);/', $line, $matches)) {
                $returnExpressions[] = $matches[1];
            }
        }
        $returnExpressions = array_unique($returnExpressions);

        if ($returnExpressions == ['$this']) {
            foreach ($codeBlocks as $codeBlock) {
                if ($codeBlock instanceof ReturnAnnotation) {
                    $codeBlock->updateTypeHint('$this');
                }
            }
        }

        return $codeBlocks;
    }
}

class BlankLinesModifier implements CodeBlockModifier
{
    /**
     * Leerzeilen nach den meisten CodeBlock.
     *
     * Gruppiert wurde bereits, aber nach dem ersten CodeBlock kommt nur dann
     * eine Leerzeile, wenn er nicht nur aus einer einzelnen Zeile besteht.
     * Ausserdem keine Leerzeile vor dem letzten CodeBlock.
     *
     * @inheritDoc
     */
    public function modifyCodeBlocks(array $codeBlocks): array
    {
        $oldType = 'CodeBlock';
        $newCodeBlocks = [];

        $codeBlocks = array_values($codeBlocks);

        foreach ($codeBlocks as $index => $codeBlock) {
            if (get_class($codeBlock) == 'BlankLine') {
                continue;
            }

            if ($index == 1) {
                $needsBlankLine = count(($codeBlocks[0])->lines) > 1;
            } else {
                $needsBlankLine = (get_class($codeBlock) != $oldType);
                $needsBlankLine &= ($index != count($codeBlocks) - 1);
            }

            if ($needsBlankLine) {
                $newCodeBlocks[] = new BlankLine(' *');
            }
            $newCodeBlocks[] = $codeBlock;
            $oldType = get_class($codeBlock);
        }

        return $newCodeBlocks;
    }
}

class ConstructorModifier implements CodeBlockModifier
{
    /** @var string $functionName */
    protected $functionName; 

    /**
     * Constructor.
     *
     * @param string $functionName
     */
    public function __construct(string $functionName)
    {
        $this->functionName = $functionName;
    }

    /**
     * @inheritDoc
     */
    public function modifyCodeBlocks(array $codeBlocks): array
    {
        if ($this->functionName == '__construct') {
            $firstBlock = array_shift($codeBlocks);
            if (count($firstBlock->lines) == 1) {
                $firstBlock->addLine(' * Constructor.');
            }
            array_unshift($codeBlocks, $firstBlock);
        }

        return $codeBlocks;
    }
}


/**
 * Klasse, die aus einer Funktionsdefinition die Parameter bestimmt.
 *
 * Aus function(string $param1, \DateTime $date) werden z.B. zwei Param-Objekte
 * erzeugt, bestehend aus varName und typeHint.
 */ 
class FunctionDefinition
{
    /** @var string $code */
    protected $code;

    /** @var string $indent */
    protected $indent;

    /** @var Param[] $params */
    protected $params = null;

    /** @var string $functionName */
    protected $functionName = '';

    public function __construct(array $functionLines)
    {
        $this->code = implode(' ', $functionLines);
    }

    /**
     * @return array
     */
    public function getParams(): array
    {
        if ($this->params === null) {
            // Den Teil in den runden Klammern herausparsen, dafür Lookarounds, s damit . auch \n matcht.
            // $doesMatch = preg_match_all('@(?<=\().*?(?=\))@s', $code, $matches);
            
            // Oder doch ohne 
            $doesMatch = preg_match_all('@\(.*?\)@s', $this->code, $matches);

            if ($doesMatch) {
                // Der letzte String in runden Klammern interessiert uns
                $lastMatch = array_pop($matches[0]);
                // Aber die runden Klammern selbst nicht
                $lastMatch = trim($lastMatch, '()');

                if (trim($lastMatch)) {
                    // Im Wesentlichen bei den Kommas splitten
                    $paramParts = preg_split('@\s*,\s*@', $lastMatch);

                    foreach ($paramParts as $paramPart) {
                        $param = new Param($paramPart);
                        $this->params[] = $param;
                    }
                }
            } else {
                $this->params = [];
            }
        }

        return $this->params ? : [];
    }

    /**
     * @return string
     */
    public function getFunctionName(): string
    {
        if (!$this->functionName) {
            if (preg_match('@function\s+(\w+)@s', $this->code, $matches)) {
                $this->functionName = $matches[1];
            }
        }
        return $this->functionName;
    }

    /**
     * @return string
     */
    public function getIndent(): string
    {
        if (!$this->indent) {
            preg_match('@^(\s*)@', $this->code, $matches);
            $this->indent = $matches[1];
        }

        return $this->indent;
    }

    /**
     * @return string
     */
    public function getReturnTypeHint(): string
    {
        if (preg_match('@:\s*(\w+)\s*{?;?\s*$@', $this->code, $matches)) {
            return $matches[1];
        }

        return '';
    }
}

class Param
{
    protected $typeHint = 'mixed';
    protected $varName;

    /**
     * Constructor.
     *
     * @param string $paramPart
     */
    public function __construct(string $paramPart)
    {
        $paramPart = str_replace('=', ' = ', $paramPart);
        $components = preg_split('@\s+@', trim($paramPart));

        // Z.B. "int $number = 0" bestünde aus 4 Kompnenten
        if (count($components) > 1) {
            $this->typeHint = $components[0];
            $this->varName = $components[1];
        } else {
            $this->varName = $components[0];
        }
    }

    /**
     * @return string
     */
    public function getVarName(): string
    {
        return $this->varName;
    }

    /**
     * @return string
     */
    public function getTypeHint(): string
    {
        return $this->typeHint;
    }

    /**
     * @return string
     */
    public function __toString(): string
    {
        return "@param {$this->typeHint} {$this->varName}";
    }
}

class OldDocBlockIsolater
{
    /**
     * @param string $code
     * @param int    $dBStartLineNumber
     * @param int    $dBEndLineNumber
     *
     * @return array
     */
    public static function getOrCreateLines(
        string $code,
        int $dBStartLineNumber,
        int $dBEndLineNumber
    ): array {
        $allCodeLineStrings = explode("\n", $code);
        $oldDBRange = $dBEndLineNumber - $dBStartLineNumber;

        return array_slice($allCodeLineStrings, $dBStartLineNumber - 1, $oldDBRange + 1);
    }
}

class ThrowsParser
{
    /**
     * @param array $codeLines
     *
     * @return array
     */
    public static function getThrowsAnnotations(array $codeLines): array
    {
        $annotations= [];

        foreach ($codeLines as $codeLine) {
            if (preg_match('|throw\s+new\s+(.?\w*Exception)|', $codeLine, $matches)) {
                $annotations[] = new ThrowsAnnotation(" * @throws {$matches[1]}");
            }
        }

        return $annotations;
    }
}

/** 
 * Hier der eigentliche "Controller-Code".
 *
 * Wir hätten den gesamten Code zur Verfügung, bisher wird aber nur der
 * alte Docblock und die eigentliche Funktion benötigt.
 */
list(
    $scriptName,
    $dBStartLineNumber,
    $dBEndLineNumber,
    $functionDefinitionStartLineNumber,
    $functionDefinitionEndLineNumber,
    $functionBodyStartLineNumber,
    $functionBodyEndLineNumber,
    $code
) = $argv;

$functionDefinitionLength = $functionDefinitionEndLineNumber - $functionDefinitionStartLineNumber + 1;
$functionDefinition = new FunctionDefinition(
    array_slice(explode("\n", $code), $functionDefinitionStartLineNumber - 1, $functionDefinitionLength)
);
$indent = $functionDefinition->getIndent();

if ($dBStartLineNumber) {
    $oldDBStrings = OldDocBlockIsolater::getOrCreateLines($code, $dBStartLineNumber, $dBEndLineNumber);
} else {
    $oldDBStrings = [$indent . '/**', $indent . '*/'];
}

$functionBodyLines = array_slice(
    explode("\n", $code),
    $functionBodyStartLineNumber,
    $functionBodyEndLineNumber - $functionBodyStartLineNumber - 1
);
$neededThrowsAnnotations = ThrowsParser::getThrowsAnnotations($functionBodyLines);

$dBBuilder = new DBBuilder();
foreach ($oldDBStrings as $oldDBString) {
    $type = $dBBuilder->addToCodeBlocks($oldDBString);
}

$dBBuilder
    ->setParams($functionDefinition->getParams())
    ->setReturnTypeHint($functionDefinition->getReturnTypeHint())
    ->setThrowsAnnotations($neededThrowsAnnotations)
    ->applyModifier(new ThrowsAnnotationLastModifier())
    ->applyModifier(new GroupAndColumizeModifier())
    ->applyModifier(new SpecialReturnTypeModifier($functionBodyLines))
    ->applyModifier(new ConstructorModifier($functionDefinition->getFunctionName()))
    ->applyModifier(new BlankLinesModifier())
    ;

echo $dBBuilder->getDocBlock($functionDefinition->getIndent());

// Debug-Ausgabe
if (false) {
    print_r([
        'debugStart' => '************',
        // 'allCodeLineStrings' => $allCodeLineStrings,
        'dBStartLineNumber' => $dBStartLineNumber,
        'dBEndLineNumber' => $dBEndLineNumber,
        'oldDBStrings' => $oldDBStrings,
        'codeBlocks' => $dBBuilder->getCodeBlocks(),
        'functionBodyStartLineNumber' => $functionBodyStartLineNumber,
        'functionBodyEndLineNumber' => $functionBodyEndLineNumber,
        'debugEnde ' => '************',
    ]);
}
die();

