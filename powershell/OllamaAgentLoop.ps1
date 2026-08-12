Set-StrictMode -Version Latest

function Resolve-NativeAgentHardwareSettings {
    param([Parameter(Mandatory)]$Configuration,[double]$VramGb=0,[double]$RamGb=0)
    $mode=[string]$Configuration.mode
    if(-not $mode -or $mode -eq 'auto'){$mode=if($VramGb -le 0){'balanced-12gb'}elseif($VramGb -le 7){'low-vram'}elseif($VramGb -le 12){'balanced-12gb'}else{'large-vram'}}
    $profile=$Configuration.profiles.PSObject.Properties[$mode]
    if(-not $profile){throw "Unknown hardware profile: $mode"}
    $settings=[ordered]@{profile=$mode;detectedVramGb=$VramGb;detectedRamGb=$RamGb}
    foreach($property in $profile.Value.PSObject.Properties){$settings[$property.Name]=$property.Value}
    if($Configuration.overrides){foreach($property in $Configuration.overrides.PSObject.Properties){if($null -ne $property.Value){$settings[$property.Name]=$property.Value}}}
    foreach($name in @('contextTokens','outputTokens','runTokens','turns','toolCalls','shellCalls','repairCycles','noProgressActions','sameActionRepeats','commandTimeoutSeconds','recentMessages','snapshotFiles','snapshotCharacters','parallelModels')){if([int]$settings[$name] -le 0){throw "Hardware setting must be positive: $name"}}
    $ranges=@{contextTokens=@(2048,131072);outputTokens=@(256,16384);runTokens=@(5000,1000000);turns=@(3,200);toolCalls=@(3,400);shellCalls=@(1,100);repairCycles=@(1,30);noProgressActions=@(2,50);sameActionRepeats=@(2,20);commandTimeoutSeconds=@(10,1800);recentMessages=@(2,50);snapshotFiles=@(1,100);snapshotCharacters=@(1000,200000);parallelModels=@(1,8)}
    foreach($name in $ranges.Keys){$value=[int]$settings[$name];$range=$ranges[$name];if($value -lt $range[0] -or $value -gt $range[1]){throw "Hardware setting $name=$value is outside supported range $($range[0])..$($range[1])"}}
    [pscustomobject]$settings
}

function Get-NativeAgentHardwareSettings {
    param([string]$ConfigurationPath)
    if(-not $ConfigurationPath){
        $sourceCandidate=Join-Path (Split-Path -Parent $PSScriptRoot) 'config\hardware-profiles.json'
        $installedCandidate=Join-Path $PSScriptRoot 'hardware-profiles.json'
        $ConfigurationPath=if(Test-Path -LiteralPath $sourceCandidate){$sourceCandidate}else{$installedCandidate}
    }
    if(-not(Test-Path -LiteralPath $ConfigurationPath)){throw "Hardware profile configuration is missing: $ConfigurationPath"}
    $configuration=Get-Content -LiteralPath $ConfigurationPath -Raw|ConvertFrom-Json
    $vram=0.0;$ram=0.0
    $nvidia=Get-Command nvidia-smi.exe,nvidia-smi -ErrorAction SilentlyContinue|Select-Object -First 1
    if($nvidia){$raw=@(& $nvidia.Source --query-gpu=memory.total --format=csv,noheader,nounits 2>$null|Select-Object -First 1);if($raw.Count){$parsed=0.0;if([double]::TryParse(([string]$raw[0]).Trim(),[ref]$parsed)){$vram=$parsed/1024}}}
    try{$ram=[math]::Round(([double](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory/1GB),1)}catch{}
    Resolve-NativeAgentHardwareSettings -Configuration $configuration -VramGb $vram -RamGb $ram
}

function Get-NativeAgentArgument {
    param($Arguments,[Parameter(Mandatory)][string]$Name,$Default=$null)
    if($null -eq $Arguments){return $Default}
    if($Arguments -is [Collections.IDictionary]){if($Arguments.Contains($Name)){return $Arguments[$Name]};return $Default}
    $p=$Arguments.PSObject.Properties[$Name]
    if($p){return $p.Value}
    return $Default
}

function Resolve-NativeAgentPath {
    param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$RelativePath,[switch]$AllowMissing)
    $root=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/')
    $raw=$RelativePath.Trim().Trim('"',"'")
    if([IO.Path]::IsPathRooted($raw)){$candidate=[IO.Path]::GetFullPath($raw)}else{$candidate=[IO.Path]::GetFullPath((Join-Path $root $raw))}
    if(-not(Test-Path -LiteralPath $candidate)){
        $segments=@($raw -split '[\\/]'|Where-Object{$_})
        if($segments.Count -ge 2 -and $segments[0] -eq $segments[1]){
            $shortened=($segments[1..($segments.Count-1)] -join [IO.Path]::DirectorySeparatorChar)
            $shortCandidate=[IO.Path]::GetFullPath((Join-Path $root $shortened))
            if(Test-Path -LiteralPath $shortCandidate){$candidate=$shortCandidate}
        }
    }
    if(-not($candidate.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or $candidate.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))){throw "Path escapes repository root: $RelativePath"}
    if(-not $AllowMissing -and -not(Test-Path -LiteralPath $candidate)){throw "Path not found: $RelativePath"}
    return $candidate
}

function Test-NativeAgentShellCommand {
    param([Parameter(Mandatory)][string]$Command)
    if($Command -match '(?i)(?:&&|\||[<>]|;|`|\$\(|Invoke-Expression|\biex\b|Remove-Item|\brm\b|\bdel\b|\brmdir\b|git\s+(?:reset|clean|checkout|restore|commit|push|rebase|merge)|shutdown|Restart-Computer|Stop-Computer)'){return $false}
    return $Command -match '^(?i)\s*(?:git\s+(?:status|diff|log|show)|(?:\.\\)?gradlew(?:\.bat)?\s+|mvn(?:\.cmd)?\s+|npm(?:\.cmd)?\s+(?:test|run\s+|--prefix\s+)|node\s+--test|python(?:\.exe)?\s+-m\s+(?:pytest|unittest|ruff|flake8|pylint)|(?:pytest|ruff|flake8|pylint)(?:\s+|$)|cargo\s+(?:check|test|build|clippy|fmt)|dotnet\s+(?:test|build)|go\s+test|powershell(?:\.exe)?\s+-NoProfile\s+-File\s+\.\\tests\\)'
}

function Get-NativeAgentLintCommand {
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $package=Join-Path $RepositoryRoot 'package.json'
    if(Test-Path -LiteralPath $package){try{$p=Get-Content $package -Raw|ConvertFrom-Json;if($p.scripts -and $p.scripts.lint){return 'npm run lint'}}catch{}}
    $pyproject=Join-Path $RepositoryRoot 'pyproject.toml'
    $pythonConfig=if(Test-Path $pyproject){Get-Content $pyproject -Raw}else{''}
    if((Test-Path (Join-Path $RepositoryRoot 'ruff.toml')) -or (Test-Path (Join-Path $RepositoryRoot '.ruff.toml')) -or $pythonConfig -match '(?im)^\s*\[tool\.ruff'){return 'python -m ruff check .'}
    if((Test-Path (Join-Path $RepositoryRoot '.flake8')) -or $pythonConfig -match '(?im)^\s*\[(?:tool\.)?flake8'){return 'python -m flake8 .'}
    $cargo=Join-Path $RepositoryRoot 'Cargo.toml';if(Test-Path $cargo){return 'cargo clippy --all-targets --all-features -- -D warnings'}
    $pom=Join-Path $RepositoryRoot 'pom.xml';if(Test-Path $pom){$x=Get-Content $pom -Raw;if($x -match 'maven-checkstyle-plugin'){return 'mvn.cmd checkstyle:check'}}
    foreach($gradleName in @('build.gradle','build.gradle.kts')){$g=Join-Path $RepositoryRoot $gradleName;if(Test-Path $g){$x=Get-Content $g -Raw;if($x -match '(?i)detekt'){return 'gradlew.bat detekt'};if($x -match '(?i)ktlint'){return 'gradlew.bat ktlintCheck'};if($x -match '(?i)checkstyle'){return 'gradlew.bat checkstyleMain'}}}
    return ''
}

function Test-NativeAgentLintCommand {
    param([string]$Command)
    [bool]($Command -match '(?i)^\s*(?:npm(?:\.cmd)?\s+run\s+lint\b|python(?:\.exe)?\s+-m\s+(?:ruff|flake8|pylint)\b|(?:ruff|flake8|pylint)\b|cargo\s+clippy\b|mvn(?:\.cmd)?\s+(?:checkstyle:check|pmd:check|spotbugs:check)\b|(?:\.\\)?gradlew(?:\.bat)?\s+(?:detekt|ktlintCheck|checkstyle\w*)\b)')
}

function Get-NativeAgentGitState {
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $old=$ErrorActionPreference
    try{
        $ErrorActionPreference='Continue'
        $inside=(& git -C $RepositoryRoot rev-parse --is-inside-work-tree 2>$null|Select-Object -First 1) -eq 'true'
        if(-not $inside){return [pscustomobject]@{available=$false;head=$null;status=@()}}
        $head=(& git -C $RepositoryRoot rev-parse HEAD 2>$null|Select-Object -First 1)
        $status=@(& git -C $RepositoryRoot status --porcelain=v1 --untracked-files=all 2>$null|ForEach-Object{[string]$_})
        [pscustomobject]@{available=$true;head=[string]$head;status=$status}
    }finally{$ErrorActionPreference=$old}
}

function Test-NativeAgentGitAcceptance {
    param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)]$Baseline)
    if(-not $Baseline.available){return [pscustomobject]@{Passed=$true;Reason='';State=(Get-NativeAgentGitState $RepositoryRoot)}}
    $current=Get-NativeAgentGitState $RepositoryRoot;$failures=New-Object Collections.Generic.List[string]
    if(-not $current.available){[void]$failures.Add('repository is no longer a Git work tree')}
    elseif($current.head -ne $Baseline.head){[void]$failures.Add('Git HEAD changed during the managed run')}
    $old=$ErrorActionPreference
    try{$ErrorActionPreference='Continue';$diffCheck=@(& git -C $RepositoryRoot diff --check 2>&1|ForEach-Object{[string]$_});$diffExit=$LASTEXITCODE}finally{$ErrorActionPreference=$old}
    if($diffExit -ne 0){[void]$failures.Add("git diff --check failed: $($diffCheck -join '; ')")}
    $forbidden=@($current.status|ForEach-Object{([string]$_).Substring([math]::Min(3,([string]$_).Length))}|Where-Object{$_ -match '(?i)(?:^|[\\/])\.aider(?:\.|[\\/])|\.orig$|\.rej$|(?:^|[\\/])native-agent-transcript\.json$'})
    if($forbidden.Count){[void]$failures.Add("forbidden agent side effects: $($forbidden -join ', ')")}
    [pscustomobject]@{Passed=($failures.Count -eq 0);Reason=($failures -join '; ');State=$current}
}

function Get-NativeAgentSyntaxDiagnostic {
    param([Parameter(Mandatory)][string]$Path)
    $extension=[IO.Path]::GetExtension($Path).ToLowerInvariant()
    if($extension -in @('.js','.cjs','.mjs')){
        $node=Get-Command node.exe,node -ErrorAction SilentlyContinue|Where-Object{$_.CommandType -eq 'Application'}|Select-Object -First 1
        if(-not $node){return ''}
        $previousErrorAction=$ErrorActionPreference
        try{$ErrorActionPreference='Continue';$output=@(& $node.Source --check $Path 2>&1|ForEach-Object{[string]$_});$exitCode=$LASTEXITCODE}
        finally{$ErrorActionPreference=$previousErrorAction}
        if($exitCode -ne 0){return "SYNTAX CHECK FAILED (node --check):`n$($output -join "`n")"}
        $diagnostics=New-Object Collections.Generic.List[string]
        [void]$diagnostics.Add('SYNTAX CHECK PASS (node --check)')
        $source=Get-Content -LiteralPath $Path -Raw
        if([IO.Path]::GetFileName($Path) -match '(?i)(?:\.test|\.spec)\.(?:js|mjs|cjs)$' -and $source -match '=>\s*(?:\+\+\s*[A-Za-z_$][\w$]*|[A-Za-z_$][\w$]*\s*\+\+)'){
            [void]$diagnostics.Add('TEST QUALITY FAILED: an injected fake clock must be side-effect free. Return the current variable (`() => now`) and advance it explicitly after Arrange on the same stateful instance.')
        }
        return ($diagnostics -join "`n")
    }
    if($extension -in @('.ps1','.psm1','.psd1')){
        $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
        if(@($errors).Count){return "SYNTAX CHECK FAILED (PowerShell parser):`n$((@($errors)|ForEach-Object{$_.Message}) -join "`n")"}
        return 'SYNTAX CHECK PASS (PowerShell parser)'
    }
    if($extension -eq '.json'){
        try{Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json|Out-Null;return 'SYNTAX CHECK PASS (JSON parser)'}catch{return "SYNTAX CHECK FAILED (JSON parser): $($_.Exception.Message)"}
    }
    if($extension -eq '.py'){
        $python=Get-Command python.exe,python -ErrorAction SilentlyContinue|Where-Object{$_.CommandType -eq 'Application'}|Select-Object -First 1
        $diagnostics=New-Object Collections.Generic.List[string]
        if($python){
            $parser='import ast,pathlib,sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig"))'
            $previousErrorAction=$ErrorActionPreference
            try{$ErrorActionPreference='Continue';$output=@(& $python.Source -c $parser $Path 2>&1|ForEach-Object{[string]$_});$exitCode=$LASTEXITCODE}
            finally{$ErrorActionPreference=$previousErrorAction}
            if($exitCode -ne 0){[void]$diagnostics.Add("SYNTAX CHECK FAILED (Python ast): $($output -join "`n")")}
            else{[void]$diagnostics.Add('SYNTAX CHECK PASS (Python ast)')}
        }
        $source=Get-Content -LiteralPath $Path -Raw
        if($source -match '(?m)\bpytest\s*\.' -and $source -notmatch '(?m)^\s*(?:import\s+pytest|from\s+pytest\s+import)\b'){
            [void]$diagnostics.Add('TEST QUALITY FAILED: pytest is used but not imported. Add `import pytest`.')
        }
        if([IO.Path]::GetFileName($Path) -match '^(?i)test_.*\.py$|.*_test\.py$' -and $source -match '(?m)\b(?:time\.)?sleep\s*\('){
            [void]$diagnostics.Add('TEST QUALITY WARNING: avoid sleep in deterministic tests; inject or fake the clock.')
        }
        return ($diagnostics -join "`n")
    }
    return ''
}

function Compress-NativeAgentToolOutput {
    param([string]$Text,[int]$MaximumCharacters=3500)
    if($null -eq $Text -or $Text.Length -le $MaximumCharacters){return $Text}
    $head=[math]::Floor($MaximumCharacters*0.3);$tail=$MaximumCharacters-$head
    return $Text.Substring(0,$head)+"`n... <tool output compacted; full output is preserved in transcript> ...`n"+$Text.Substring($Text.Length-$tail)
}

function Invoke-NativeAgentTool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Arguments,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [switch]$ReadOnly,[switch]$AllowDependencyChanges,[int]$CommandTimeoutSeconds=300
    )
    $output='';$changed=$false
    switch($Name){
        'list_files' {
            $relative=[string](Get-NativeAgentArgument $Arguments 'path' '.')
            $pattern=[string](Get-NativeAgentArgument $Arguments 'pattern' '*')
            if($pattern -match '[\\/]' -or $pattern.Contains('**')){$pattern='*'}
            $path=Resolve-NativeAgentPath $RepositoryRoot $relative
            $items=@(Get-ChildItem -LiteralPath $path -Recurse -File -Filter $pattern -ErrorAction Stop|Where-Object{$_.FullName -notmatch '[\\/](?:\.git|node_modules|target|build|dist|\.gradle|\.idea|\.venv|venv)[\\/]'}|Select-Object -First 400)
            $output=($items|ForEach-Object{$_.FullName.Substring(([IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/')).Length+1)}) -join "`n"
        }
        'read_file' {
            $relative=[string](Get-NativeAgentArgument $Arguments 'path')
            $path=Resolve-NativeAgentPath $RepositoryRoot $relative
            $start=[math]::Max(1,[int](Get-NativeAgentArgument $Arguments 'start_line' 1));$end=[int](Get-NativeAgentArgument $Arguments 'end_line' ($start+399))
            $all=@(Get-Content -LiteralPath $path -ErrorAction Stop);$last=[math]::Min($all.Count,$end)
            if($last -ge $start){
                $rows=for($i=$start;$i -le $last;$i++){('{0,5}: {1}' -f $i,$all[$i-1])}
                $boundary=if($last -eq $all.Count){'EOF'}else{"more lines available after $last"}
                $output=("[lines $start-$last of $($all.Count); $boundary]`n"+($rows -join "`n"))
            }
        }
        'search_text' {
            $query=[string](Get-NativeAgentArgument $Arguments 'query');if([string]::IsNullOrWhiteSpace($query)){throw 'search_text requires query'}
            $relative=[string](Get-NativeAgentArgument $Arguments 'path' '.');$path=Resolve-NativeAgentPath $RepositoryRoot $relative
            $glob=[string](Get-NativeAgentArgument $Arguments 'glob' '*')
            if($glob -match '[\\/]' -or $glob.Contains('**')){$glob='*'}
            $files=if(Test-Path -LiteralPath $path -PathType Leaf){@((Get-Item -LiteralPath $path))}else{@(Get-ChildItem -LiteralPath $path -Recurse -File -Filter $glob -ErrorAction Stop)}
            $matches=@($files|Where-Object{$_.FullName -notmatch '[\\/](?:\.git|node_modules|target|build|dist|\.gradle|\.idea|\.venv|venv)[\\/]'}|Select-String -SimpleMatch -Pattern $query -ErrorAction SilentlyContinue|Select-Object -First 250)
            $output=($matches|ForEach-Object{"$($_.Path):$($_.LineNumber): $($_.Line.Trim())"}) -join "`n"
            if([string]::IsNullOrWhiteSpace($output)){$output='<no matches>'}
        }
        'write_file' {
            if($ReadOnly){throw 'write_file is disabled in read-only mode'}
            $relative=[string](Get-NativeAgentArgument $Arguments 'path');$content=[string](Get-NativeAgentArgument $Arguments 'content')
            $leaf=[IO.Path]::GetFileName($relative)
            if($leaf -match '^(?i)(\.env(?:\..+)?|id_rsa|id_ed25519|credentials\.json|secrets?\.(?:json|ya?ml|toml)|.+\.(?:pem|p12|pfx|key))$'){throw "Refusing to write secret-looking file: $relative"}
            if(-not $AllowDependencyChanges -and $leaf -match '^(?i)(Cargo\.toml|Cargo\.lock|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|pom\.xml|build\.gradle|build\.gradle\.kts|pyproject\.toml|requirements\.txt)$'){throw "Dependency file requires explicit opt-in: $relative"}
            $path=Resolve-NativeAgentPath $RepositoryRoot $relative -AllowMissing
            if(Test-Path -LiteralPath $path){throw 'write_file creates new files only. For an existing short placeholder whose complete content you read, use rewrite_file; otherwise use replace_text or replace_lines.'}
            $parent=Split-Path -Parent $path;if(-not(Test-Path $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
            Set-Content -LiteralPath $path -Encoding UTF8 -Value $content;$changed=$true;$output="Wrote $relative ($($content.Length) chars)"
            $syntax=Get-NativeAgentSyntaxDiagnostic $path;if($syntax){$output+="`n$syntax"}
        }
        'rewrite_file' {
            if($ReadOnly){throw 'rewrite_file is disabled in read-only mode'}
            $relative=[string](Get-NativeAgentArgument $Arguments 'path');$content=[string](Get-NativeAgentArgument $Arguments 'content')
            $leaf=[IO.Path]::GetFileName($relative)
            if($leaf -match '^(?i)(\.env(?:\..+)?|id_rsa|id_ed25519|credentials\.json|secrets?\.(?:json|ya?ml|toml)|.+\.(?:pem|p12|pfx|key))$'){throw "Refusing to write secret-looking file: $relative"}
            if(-not $AllowDependencyChanges -and $leaf -match '^(?i)(Cargo\.toml|Cargo\.lock|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|pom\.xml|build\.gradle|build\.gradle\.kts|pyproject\.toml|requirements\.txt)$'){throw "Dependency file requires explicit opt-in: $relative"}
            $path=Resolve-NativeAgentPath $RepositoryRoot $relative
            if($content.Length -gt 200000){throw 'rewrite_file content exceeds 200000 character safety limit'}
            $existing=[string](Get-Content -LiteralPath $path -Raw)
            if($existing -ceq $content){throw "rewrite_file rejected no-op content for $relative; choose the next required file or run verification"}
            if($existing -match '(?m)^\s*module\.exports\s*=' -and $content -notmatch '(?m)^\s*module\.exports\s*='){
                throw "rewrite_file rejected removal of the existing CommonJS module.exports contract in $relative"
            }
            if($existing -match '(?m)^\s*package\s+[A-Za-z_][\w.]*\s*;' -and $content -notmatch '(?m)^\s*package\s+[A-Za-z_][\w.]*\s*;'){
                throw "rewrite_file rejected removal of the existing Java package declaration in $relative"
            }
            if($existing.Length -ge 300 -and $content.Length -lt [math]::Floor($existing.Length*0.40)){
                throw "rewrite_file rejected suspicious truncation of $relative from $($existing.Length) to $($content.Length) characters; use a grounded replace operation or provide the complete file"
            }
            Set-Content -LiteralPath $path -Encoding UTF8 -NoNewline -Value $content
            $changed=$true;$output="Rewrote existing file $relative ($($content.Length) chars)"
            $syntax=Get-NativeAgentSyntaxDiagnostic $path;if($syntax){$output+="`n$syntax"}
        }
        'replace_lines' {
            if($ReadOnly){throw 'replace_lines is disabled in read-only mode'}
            $relative=[string](Get-NativeAgentArgument $Arguments 'path');$start=[int](Get-NativeAgentArgument $Arguments 'start_line' 0);$end=[int](Get-NativeAgentArgument $Arguments 'end_line' 0);$replacement=[string](Get-NativeAgentArgument $Arguments 'content' '')
            $path=Resolve-NativeAgentPath $RepositoryRoot $relative
            $lines=@(Get-Content -LiteralPath $path -ErrorAction Stop)
            if($start -lt 1 -or $end -lt $start -or $end -gt $lines.Count){throw "replace_lines range $start..$end is outside file length $($lines.Count)"}
            $updated=New-Object Collections.Generic.List[string]
            if($start -gt 1){$updated.AddRange([string[]]$lines[0..($start-2)])}
            if($replacement.Length){$updated.AddRange([string[]]($replacement -split "`r?`n"))}
            if($end -lt $lines.Count){$updated.AddRange([string[]]$lines[$end..($lines.Count-1)])}
            Set-Content -LiteralPath $path -Encoding UTF8 -Value $updated
            $after=@(Get-Content -LiteralPath $path)
            $from=[math]::Max(1,$start-2);$to=[math]::Min($after.Count,$start+([math]::Max(1,($replacement -split "`r?`n").Count))+2)
            $preview=for($line=$from;$line -le $to;$line++){'{0,5}: {1}' -f $line,$after[$line-1]}
            $changed=$true;$output="Replaced lines $start..$end in $relative. Result:`n$($preview -join "`n")"
            $syntax=Get-NativeAgentSyntaxDiagnostic $path;if($syntax){$output+="`n$syntax"}
        }
        'replace_text' {
            if($ReadOnly){throw 'replace_text is disabled in read-only mode'}
            $relative=[string](Get-NativeAgentArgument $Arguments 'path');$old=[string](Get-NativeAgentArgument $Arguments 'old_text');$new=[string](Get-NativeAgentArgument $Arguments 'new_text')
            $leaf=[IO.Path]::GetFileName($relative)
            if(-not $AllowDependencyChanges -and $leaf -match '^(?i)(Cargo\.toml|Cargo\.lock|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|pom\.xml|build\.gradle|build\.gradle\.kts|pyproject\.toml|requirements\.txt)$'){throw "Dependency file requires explicit opt-in: $relative"}
            if([string]::IsNullOrEmpty($old)){throw 'replace_text requires non-empty old_text'}
            $path=Resolve-NativeAgentPath $RepositoryRoot $relative;$text=Get-Content -LiteralPath $path -Raw
            $count=([regex]::Matches($text,[regex]::Escape($old))).Count
            if($count -ne 1){
                # A stale exact fragment is common after earlier edits. Return
                # the current bounded file so the model can recover without a
                # wasteful search/replace cycle.
                $current=@(Get-Content -LiteralPath $path|Select-Object -First 160)
                $numbered=for($i=0;$i -lt $current.Count;$i++){'{0,5}: {1}' -f ($i+1),$current[$i]}
                throw "replace_text expected exactly one match, found $count. Current file:`n$($numbered -join "`n")`nIf this is a short placeholder and the complete file is shown, use rewrite_file with the complete desired content."
            }
            $updated=$text.Replace($old,$new)
            if($updated -ceq $text){throw "replace_text rejected a no-op replacement in $relative; old_text and new_text must produce a byte-changing edit"}
            Set-Content -LiteralPath $path -Encoding UTF8 -NoNewline -Value $updated;$changed=$true;$output="Replaced one occurrence in $relative"
            $syntax=Get-NativeAgentSyntaxDiagnostic $path;if($syntax){$output+="`n$syntax"}
        }
        'shell' {
            if($ReadOnly -and ([string](Get-NativeAgentArgument $Arguments 'command')) -notmatch '^(?i)\s*git\s+(?:status|diff|log|show)'){throw 'Only read-only Git shell commands are enabled in read-only mode'}
            $command=[string](Get-NativeAgentArgument $Arguments 'command')
            if(-not(Test-NativeAgentShellCommand $command)){
                $example=if($command -match '(?i)pytest|\.py\b'){'python -m pytest -q'}elseif($command -match '(?i)gradle'){'gradlew.bat test'}elseif($command -match '(?i)mvn|java'){'mvn.cmd test'}elseif($command -match '(?i)cargo|rust'){'cargo test'}elseif($command -match '(?i)npm|node'){'npm test'}else{'git diff --check'}
                $readHint=if($command -match '(?i)^\s*(?:cat|head|tail|type|Get-Content|python\s+[^\s]+\.py)\b'){' To inspect a file, call the read_file tool with path/start_line/end_line; shell is intentionally not a file reader.'}else{''}
                throw "Shell command is outside the managed allowlist: $command.$readHint Run from the existing repository root with no cd, /repo, pipes, redirection, or chaining. Allowed verification example: $example"
            }
            # Resolve global executables before spawning a clean child shell. This
            # avoids malformed user PATH entries changing which program is executed.
            if($command -match '^\s*(git|npm|node|mvn|cargo|dotnet|go|pytest|python)(?:\.cmd|\.exe)?\s+(.+)$'){
                $toolName=$matches[1];$toolArgs=$matches[2]
                $resolvedTool=Get-Command $toolName,$($toolName+'.cmd'),$($toolName+'.exe') -ErrorAction SilentlyContinue|Where-Object{$_.CommandType -eq 'Application'}|Select-Object -First 1
                if($resolvedTool){$escapedTool=$resolvedTool.Source.Replace("'","''");$command="& '$escapedTool' $toolArgs"}
                elseif($toolName -eq 'pytest'){
                    $pythonTool=Get-Command python.exe,python -ErrorAction SilentlyContinue|Where-Object{$_.CommandType -eq 'Application'}|Select-Object -First 1
                    if($pythonTool){$escapedTool=$pythonTool.Source.Replace("'","''");$command="& '$escapedTool' -m pytest $toolArgs"}
                }
            }
            $timeout=[math]::Min($CommandTimeoutSeconds,[math]::Max(1,[int](Get-NativeAgentArgument $Arguments 'timeout_seconds' $CommandTimeoutSeconds)))
            $runner=Join-Path ([IO.Path]::GetTempPath()) ('lca-shell-'+[guid]::NewGuid().ToString('N')+'.ps1')
            try{
                $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=(Get-Command powershell.exe -ErrorAction Stop).Source;$psi.Arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$runner+'"';$psi.WorkingDirectory=$RepositoryRoot;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
                $toolDirectories=New-Object Collections.Generic.List[string]
                foreach($commandName in @('node.exe','npm.cmd','git.exe')){$resolved=Get-Command $commandName -ErrorAction SilentlyContinue|Select-Object -First 1;if($resolved){$dir=Split-Path -Parent $resolved.Source;if(-not $toolDirectories.Contains($dir)){[void]$toolDirectories.Add($dir)}}}
                $pathPrefix=(($toolDirectories -join ';')+';').Replace("'","''")
                Set-Content -LiteralPath $runner -Encoding UTF8 -Value @("`$env:Path='$pathPrefix'+`$env:Path",$command,"if (-not `$?) { if (`$null -ne `$LASTEXITCODE) { exit `$LASTEXITCODE }; exit 1 }","if (`$null -ne `$LASTEXITCODE) { exit `$LASTEXITCODE }")
                $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;if(-not $p.Start()){throw 'Unable to start shell command'}
                $outTask=$p.StandardOutput.ReadToEndAsync();$errTask=$p.StandardError.ReadToEndAsync()
                if(-not $p.WaitForExit($timeout*1000)){try{$p.Kill()}catch{};throw "Command timed out after ${timeout}s"}
                $p.WaitForExit();$exitCode=[int]$p.ExitCode;$output=($outTask.GetAwaiter().GetResult()+"`n"+$errTask.GetAwaiter().GetResult()).Trim();$output="ExitCode: $exitCode`n$output";$p.Dispose()
                if($exitCode -ne 0){throw "Command failed with exit code ${exitCode}: $output"}
            }finally{Remove-Item $runner -Force -ErrorAction SilentlyContinue}
        }
        default {throw "Unknown native agent tool: $Name"}
    }
    return [pscustomobject]@{Success=$true;Output=$output;Changed=$changed;Name=$Name}
}

function Get-NativeOllamaTools {
    param([switch]$ReadOnly)
    $defs=@(
        @('list_files','List repository files','{"path":{"type":"string"},"pattern":{"type":"string"}}',@()),
        @('read_file','Read a repository text file with line numbers','{"path":{"type":"string"},"start_line":{"type":"integer"},"end_line":{"type":"integer"}}',@('path')),
        @('search_text','Search literal text in repository files','{"query":{"type":"string"},"path":{"type":"string"},"glob":{"type":"string"}}',@('query')),
        @('write_file','Create a new repository text file. Never use for an existing file.','{"path":{"type":"string"},"content":{"type":"string"}}',@('path','content')),
        @('replace_text','Replace one exact text occurrence in a file','{"path":{"type":"string"},"old_text":{"type":"string"},"new_text":{"type":"string"}}',@('path','old_text','new_text')),
        @('rewrite_file','Rewrite one existing small text file atomically. Prefer this after reading the complete file when several related edits are needed.','{"path":{"type":"string"},"content":{"type":"string"}}',@('path','content')),
        @('replace_lines','Replace an inclusive line range in an existing file after reading those lines','{"path":{"type":"string"},"start_line":{"type":"integer"},"end_line":{"type":"integer"},"content":{"type":"string"}}',@('path','start_line','end_line','content')),
        @('shell','Run an allowlisted build, test, or read-only Git command','{"command":{"type":"string"},"timeout_seconds":{"type":"integer"}}',@('command'))
    )
    foreach($d in $defs){
        if($ReadOnly -and $d[0] -in @('write_file','replace_text','rewrite_file','replace_lines')){continue}
        [ordered]@{type='function';function=[ordered]@{name=$d[0];description=$d[1];parameters=[ordered]@{type='object';properties=($d[2]|ConvertFrom-Json);required=$d[3]}}}
    }
}

function Test-NativeAgentVerificationCommand {
    param([string]$Command)
    if([string]::IsNullOrWhiteSpace($Command)){return $false}
    return [bool]($Command -match '(?i)^\s*(?:git\s+diff\s+--check\b|(?:npm|pnpm|yarn)(?:\.cmd)?\s+(?:test\b|run\s+(?:test|build|lint|check)\b)|(?:mvn|mvnw|gradle|gradlew)(?:\.cmd|\.bat)?\b|cargo\s+(?:test|check|build|clippy)\b|dotnet\s+(?:test|build)\b|go\s+test\b|pytest\b|python(?:\.exe)?\s+-m\s+pytest\b|node(?:\.exe)?\s+--test\b)')
}

function Get-NativeAgentCompactedHistoryMessage {
    param([Parameter(Mandatory)]$Message)
    # Preserve the raw model call in transcript, but do not resend large write
    # payloads on every later turn. The repository is the source of truth after
    # execution and can be read again when repair needs the current content.
    $copy=($Message|ConvertTo-Json -Depth 30|ConvertFrom-Json)
    foreach($call in @(Get-NativeAgentArgument $copy 'tool_calls' @())){
        $fn=Get-NativeAgentArgument $call 'function'
        $args=Get-NativeAgentArgument $fn 'arguments' @{}
        $wasString=$args -is [string]
        if($wasString){try{$args=$args|ConvertFrom-Json}catch{continue}}
        foreach($field in @('content','new_text','old_text')){
            $property=$args.PSObject.Properties[$field]
            if($property -and ([string]$property.Value).Length -gt 400){
                $length=([string]$property.Value).Length
                $property.Value="<payload compacted after tool execution; chars=$length; read the repository file if needed>"
            }
        }
        if($wasString){$fn.arguments=$args|ConvertTo-Json -Depth 10 -Compress}else{$fn.arguments=$args}
    }
    return $copy
}

function Test-NativeAgentTaskAcceptance {
    param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$Task)
    $failures=New-Object Collections.Generic.List[string]
    $testFiles=@(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -ErrorAction SilentlyContinue|Where-Object{
        $_.FullName -notmatch '[\\/](?:\.git|\.venv|venv|node_modules|target|build|dist|__pycache__)[\\/]' -and
        ($_.Name -match '^(?:test_.+|.+\.test|.+\.spec)\.(?:py|js|ts|jsx|tsx)$' -or $_.FullName -match '[\\/]src[\\/]test[\\/]')
    })
    if($Task -match '(?i)replace\s+(?:the\s+)?placeholder'){
        foreach($file in $testFiles){
            $text=Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if($text -match '(?im)\btest_placeholder\b|replace\s+with\s+behavioral\s+tests|\bTODO\b.*\btest'){
                $relative=$file.FullName.Substring($RepositoryRoot.TrimEnd('\','/').Length).TrimStart('\','/')
                [void]$failures.Add("required placeholder replacement is incomplete in $relative")
            }
        }
    }
    if($Task -match '(?i)(\d+)\s*-\s*(\d+)\s+(?:[a-z][a-z0-9_-]*\s+){0,5}tests?\b'){
        $minimum=[int]$Matches[1];$maximum=[int]$Matches[2];$count=0
        foreach($file in $testFiles){
            $text=Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if($file.Extension -eq '.py'){$count+=([regex]::Matches($text,'(?m)^\s*def\s+test_')).Count}
            elseif($file.Extension -in @('.js','.mjs','.cjs','.ts','.tsx','.jsx')){$count+=([regex]::Matches($text,'(?m)^\s*(?:test|it)\s*\(')).Count}
            elseif($file.Extension -in @('.java','.kt','.kts')){$count+=([regex]::Matches($text,'(?m)^\s*@Test\b')).Count}
            elseif($file.Extension -eq '.rs'){$count+=([regex]::Matches($text,'(?m)^\s*#\s*\[test\]')).Count}
        }
        if($count -lt $minimum -or $count -gt $maximum){[void]$failures.Add("task requires $minimum-$maximum tests, but repository inspection found $count")}
    }
    $contractTypes=@([regex]::Matches($Task,'\b[A-Z][A-Za-z0-9_]+(?=\s*\()')|ForEach-Object{$_.Value}|Select-Object -Unique)
    foreach($type in $contractTypes){
        foreach($file in @($testFiles|Where-Object{$_.Extension -eq '.py'})){
            $text=Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if($text -match ("\b"+[regex]::Escape($type)+"\s*\(") -and
               $text -notmatch ("(?m)^\s*(?:from\s+\S+\s+import\s+[^\r\n]*\b"+[regex]::Escape($type)+"\b|(?:class|def)\s+"+[regex]::Escape($type)+"\b)")){
                $relative=$file.FullName.Substring($RepositoryRoot.TrimEnd('\','/').Length).TrimStart('\','/')
                [void]$failures.Add("$relative uses $type but does not import or define it")
            }
        }
    }
    [pscustomobject]@{Passed=($failures.Count -eq 0);Reason=($failures -join '; ')}
}

function Get-NativeAgentInitialSnapshot {
    param([Parameter(Mandatory)][string]$RepositoryRoot,[int]$MaximumFiles=8,[int]$MaximumCharacters=16000)
    $extensions=@('.py','.js','.ts','.jsx','.tsx','.java','.kt','.kts','.rs','.ps1','.psm1','.md','.json','.xml','.html','.css')
    $files=@(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -ErrorAction SilentlyContinue|Where-Object{
        $extensions -contains $_.Extension.ToLowerInvariant() -and $_.Length -le 8000 -and
        $_.FullName -notmatch '[\\/](?:\.git|\.venv|venv|node_modules|target|build|dist|__pycache__)[\\/]'
    }|Sort-Object FullName|Select-Object -First $MaximumFiles)
    $parts=New-Object Collections.Generic.List[string];$used=0
    foreach($file in $files){
        $relative=$file.FullName.Substring($RepositoryRoot.TrimEnd('\','/').Length).TrimStart('\','/')
        $content=Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        $block="--- $relative ---`n$content"
        if($used+$block.Length -gt $MaximumCharacters){break}
        [void]$parts.Add($block);$used+=$block.Length
    }
    if(-not $parts.Count){return ''}
    "INITIAL REPOSITORY SNAPSHOT (authoritative at turn 1; do not reread these short files before the first edit):`n"+($parts -join "`n")
}

function Get-NativeAgentActiveMessages {
    param([Parameter(Mandatory)]$Messages,[int]$RecentMessages=6)
    $all=@($Messages)
    if($all.Count -le (2+$RecentMessages)){return $all}
    $active=New-Object Collections.ArrayList
    # System and original task/requirements are stable authoritative context.
    [void]$active.Add($all[0]);[void]$active.Add($all[1])
    [void]$active.Add([ordered]@{role='user';content='Earlier conversational/tool chatter was compacted. The repository contains all successful writes; reread only the exact file/region needed for the current failure. Continue from the recent actions below.'})
    $start=[math]::Max(2,$all.Count-$RecentMessages)
    for($i=$start;$i -lt $all.Count;$i++){[void]$active.Add($all[$i])}
    return @($active)
}

function Invoke-OllamaNativeChat {
    param([Parameter(Mandatory)]$Request,[scriptblock]$OnChunk)
    $Request['stream']=$true
    $body=$Request|ConvertTo-Json -Depth 30 -Compress
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
    $client=New-Object Net.Http.HttpClient
    $client.Timeout=[TimeSpan]::FromMinutes(3)
    $content=New-Object Net.Http.StringContent($body,[Text.Encoding]::UTF8,'application/json')
    $stream=$null;$reader=$null;$response=$null
    $text=New-Object Text.StringBuilder;$toolCalls=New-Object Collections.ArrayList
    $promptTokens=0;$outputTokens=0;$loadMs=0;$totalMs=0
    try{
        $requestMessage=New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Post,'http://127.0.0.1:11434/api/chat');$requestMessage.Content=$content
        $response=$client.SendAsync($requestMessage,[Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode()|Out-Null
        $stream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult();$reader=New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8)
        while(-not $reader.EndOfStream){
            $line=$reader.ReadLine();if([string]::IsNullOrWhiteSpace($line)){continue}
            $chunk=$line|ConvertFrom-Json
            $chunkError=[string](Get-NativeAgentArgument $chunk 'error' '')
            if($chunkError){throw "Ollama streaming error: $chunkError"}
            $chunkMessage=Get-NativeAgentArgument $chunk 'message' $null
            if($chunkMessage){
                $piece=[string](Get-NativeAgentArgument $chunkMessage 'content' '')
                if($piece){[void]$text.Append($piece);if($OnChunk){& $OnChunk $piece}}
                foreach($tc in @(Get-NativeAgentArgument $chunkMessage 'tool_calls' @())){[void]$toolCalls.Add($tc)}
            }
            if([bool](Get-NativeAgentArgument $chunk 'done' $false)){$promptTokens=[int](Get-NativeAgentArgument $chunk 'prompt_eval_count' 0);$outputTokens=[int](Get-NativeAgentArgument $chunk 'eval_count' 0);$loadMs=[math]::Round(([double](Get-NativeAgentArgument $chunk 'load_duration' 0)/1000000),0);$totalMs=[math]::Round(([double](Get-NativeAgentArgument $chunk 'total_duration' 0)/1000000),0)}
        }
    }finally{
        if($reader){$reader.Dispose()};if($stream){$stream.Dispose()};if($response){$response.Dispose()};if($content){$content.Dispose()};if($client){$client.Dispose()}
    }
    return [pscustomobject]@{Message=[ordered]@{role='assistant';content=$text.ToString();tool_calls=@($toolCalls)};PromptTokens=$promptTokens;OutputTokens=$outputTokens;LoadMilliseconds=$loadMs;TotalMilliseconds=$totalMs}
}

function Invoke-NativeOllamaAgentLoop {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$SystemPrompt,[Parameter(Mandatory)][string]$Task,
        [scriptblock]$ChatInvoker=${function:Invoke-OllamaNativeChat},[int]$MaxTurns=24,[switch]$ReadOnly,[switch]$Quiet,
        [string]$TranscriptPath,[string]$RunDirectory,[switch]$AllowDependencyChanges,
        [int]$MaxToolCalls=48,[int]$MaxShellCalls=12,[int]$MaxRepairCycles=3,[int]$MaxNoProgressActions=6,[int]$MaxSameActionRepeats=3,[int]$MaxTokens=80000
    )
    if(-not(Get-Command New-LsdaMicroRun -ErrorAction SilentlyContinue)){
        $runtimePath=Join-Path (Split-Path -Parent $PSCommandPath) 'MicroRuntime.ps1'
        if(Test-Path -LiteralPath $runtimePath){. $runtimePath}
    }
    $hardware=Get-NativeAgentHardwareSettings
    if(-not $PSBoundParameters.ContainsKey('MaxTurns')){$MaxTurns=[int]$hardware.turns}
    if(-not $PSBoundParameters.ContainsKey('MaxTokens')){$MaxTokens=[int]$hardware.runTokens}
    if(-not $PSBoundParameters.ContainsKey('MaxToolCalls')){$MaxToolCalls=[int]$hardware.toolCalls}
    if(-not $PSBoundParameters.ContainsKey('MaxShellCalls')){$MaxShellCalls=[int]$hardware.shellCalls}
    if(-not $PSBoundParameters.ContainsKey('MaxRepairCycles')){$MaxRepairCycles=[int]$hardware.repairCycles}
    if(-not $PSBoundParameters.ContainsKey('MaxNoProgressActions')){$MaxNoProgressActions=[int]$hardware.noProgressActions}
    if(-not $PSBoundParameters.ContainsKey('MaxSameActionRepeats')){$MaxSameActionRepeats=[int]$hardware.sameActionRepeats}
    if(-not $RunDirectory){$RunDirectory=if($TranscriptPath){Split-Path -Parent $TranscriptPath}else{Join-Path ([IO.Path]::GetTempPath()) ('lsda-run-'+[guid]::NewGuid().ToString('N'))}}
    $gitBaseline=Get-NativeAgentGitState -RepositoryRoot $RepositoryRoot
    $lintCommand=if($ReadOnly){''}else{Get-NativeAgentLintCommand -RepositoryRoot $RepositoryRoot}
    $runtime=New-LsdaMicroRun -RepositoryRoot $RepositoryRoot -RunDirectory $RunDirectory -ReadOnly:$ReadOnly -MaxTurns $MaxTurns -MaxToolCalls $MaxToolCalls -MaxShellCalls $MaxShellCalls -MaxRepairCycles $MaxRepairCycles -MaxNoProgressActions $MaxNoProgressActions -MaxSameActionRepeats $MaxSameActionRepeats -MaxTokens $MaxTokens -RequireLint:([bool]$lintCommand)
    $runtime.Data|Add-Member -NotePropertyName hardware -NotePropertyValue $hardware -Force;Save-LsdaMicroRun $runtime
    $runtime.Data|Add-Member -NotePropertyName git -NotePropertyValue ([pscustomobject]@{baseline=$gitBaseline;final=$null;passed=$false;reason=$null}) -Force;Save-LsdaMicroRun $runtime
    $messages=New-Object Collections.ArrayList
    [void]$messages.Add([ordered]@{role='system';content=$SystemPrompt})
    $snapshot=Get-NativeAgentInitialSnapshot -RepositoryRoot $RepositoryRoot -MaximumFiles ([int]$hardware.snapshotFiles) -MaximumCharacters ([int]$hardware.snapshotCharacters)
    $taskRequiresTestChanges=[bool]($Task -match '(?i)(?:add|write|create|update|добав|напис|созда|обнов).{0,60}(?:regression|meaningful|boundary|hidden|автотест|тест|coverage)')
    $lintRequirement=if($lintCommand){"`n`nREQUIRED LINT GATE: after the final edit run exactly `$lintCommand` and repair blocking findings. Tests/build and lint are separate completion evidence."}else{''}
    $timeTestRequirement=if(-not $ReadOnly -and $Task -match '(?i)\b(?:ttl|expir(?:y|e|ed|ation)|timeout|clock|time[- ]boundary)\b'){
        "`n`nDETERMINISTIC TIME-TEST CONTRACT: inject one mutable, side-effect-free clock (`() => now`), arrange state on one stateful instance, then explicitly advance that same clock before asserting the boundary on that same instance. Never increment time inside the clock callback. Creating a new store/service after advancing time creates empty state and is not evidence of expiry. Verify the arithmetic: createdAt + TTL <= now for expired data and > now for live data."
    }else{''}
    $testScopeRequirement=if(-not $ReadOnly -and $Task -match '(?i)\b(?:tests?|testing|coverage|тест|тесты|покрытие)\b'){
        "`n`nSPEC-BOUND TEST CONTRACT: test every requested documented behavior, including negative and boundary cases, but do not invent new public methods, return fields, validation rules, or exceptions absent from the requirements and existing public contract. Prefer observable behavior over implementation details."
    }else{''}
    $modeRequirement=if($ReadOnly){
        "`n`nREAD-ONLY MODE: only inspect repository evidence and report findings. Never propose or attempt a write/edit tool call. Keep analysis concise."
    }else{
        "`n`nMUTATION MODE: use the initial snapshot as current evidence, make the smallest grounded edits, update requested tests, and verify promptly. Batch known acceptance edits without rereading after every successful edit. Re-read each changed file once only after the edit batch, unless a failed tool supplies new defect evidence. Keep prose minimal between tool calls."
    }
    $initialTask=$(if($snapshot){$Task+"`n`n"+$snapshot}else{$Task})+$modeRequirement+$lintRequirement+$timeTestRequirement+$testScopeRequirement
    [void]$messages.Add([ordered]@{role='user';content=$initialTask})
    $requiredComplianceIds=@([regex]::Matches($initialTask,'(?i)REQ[-\u2010-\u2015]?\d{2}')|ForEach-Object{($_.Value -replace '[\u2010-\u2015]','-').ToUpperInvariant()}|Select-Object -Unique)
    $transcript=New-Object Collections.ArrayList;$promptTotal=0;$outputTotal=0;$completed=$false;$final='';$lastToolFingerprint='';$repeatedToolCount=0;$emptyTurnCount=0;$toolSignatureCounts=@{};$writePathCounts=@{};$readPaths=@{};$postEditReadPaths=@{};$repairReadPaths=@{};$investigationCalls=0;$repairReadsRemaining=0;$phaseViolationCount=0;$mustEdit=$false;$mustVerify=$false;$forceFinal=$false
    $declaredReadCount=0
    if($ReadOnly){
        $numberWords=@{one=1;two=2;three=3;four=4;five=5;six=6;seven=7;eight=8;nine=9;ten=10}
        if($Task -match '(?i)\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+files?\b'){
            $declaredReadCount=if($Matches[1] -match '^\d+$'){[int]$Matches[1]}else{[int]$numberWords[$Matches[1].ToLowerInvariant()]}
        }
    }
    for($turn=1;$turn -le $MaxTurns;$turn++){
        if(-not $Quiet){Write-Host "  [agent] turn $turn/$MaxTurns - $Model" -ForegroundColor DarkGray}
        # Tool execution needs short observable decisions. Disabling extended
        # thinking prevents Qwen from consuming the entire turn without
        # emitting content or a tool call.
        # A complete multi-file edit/tool payload can exceed 2k tokens (notably
        # Java/Kotlin and behavioral test suites). Keep a bounded 4k response;
        # the run-level token budget and watchdog still cap total consumption.
        $request=[ordered]@{model=$Model;stream=$false;think=$false;messages=@(Get-NativeAgentActiveMessages $messages -RecentMessages ([int]$hardware.recentMessages));options=@{temperature=0;num_ctx=[int]$hardware.contextTokens;num_predict=[int]$hardware.outputTokens};keep_alive='15m'}
        if(-not $forceFinal){
            $availableTools=@(Get-NativeOllamaTools -ReadOnly:$ReadOnly)
            if($mustVerify){$availableTools=@($availableTools|Where-Object{[string]$_.function.name -eq 'shell'})}
            elseif($mustEdit){
                $repairTools=@('write_file','rewrite_file','replace_text','replace_lines')
                if($repairReadsRemaining -gt 0){$repairTools+='read_file'}
                $availableTools=@($availableTools|Where-Object{[string]$_.function.name -in $repairTools})
            }
            $request.tools=$availableTools
        }
        $reply=& $ChatInvoker $request {param($chunk)if(-not $Quiet){Write-Host $chunk -NoNewline}}
        $promptTotal+=[int]$reply.PromptTokens;$outputTotal+=[int]$reply.OutputTokens
        $budgetBlock=Add-LsdaMicroTurn -Run $runtime -PromptTokens ([int]$reply.PromptTokens) -OutputTokens ([int]$reply.OutputTokens)
        if($budgetBlock){Stop-LsdaMicroRun -Run $runtime -Reason $budgetBlock;$final="TASK_BLOCKED`nFINAL RESULT: BLOCKED`nWORKFLOW: native-agent`n`nSUMMARY`nRuntime stopped the run: $budgetBlock.";break}
        $message=$reply.Message;$content=[string](Get-NativeAgentArgument $message 'content' '')
        $toolCalls=@(Get-NativeAgentArgument $message 'tool_calls' @())
        $bridgedTextTool=$false
        if($toolCalls.Count -eq 0 -and $content -match '(?is)^\s*<tool_call>\s*(\{.*\})\s*</tool_call>\s*$'){
            try{
                $textCall=$Matches[1]|ConvertFrom-Json
                $textName=[string](Get-NativeAgentArgument $textCall 'name' '')
                $textArguments=Get-NativeAgentArgument $textCall 'arguments' $null
                $knownTools=@(Get-NativeOllamaTools -ReadOnly:$ReadOnly|ForEach-Object{[string]$_.function.name})
                if($textName -and $null -ne $textArguments -and $knownTools -contains $textName){
                    $toolCalls=@([ordered]@{function=[ordered]@{name=$textName;arguments=$textArguments}});$content='';$bridgedTextTool=$true
                }
            }catch{}
        }
        if($bridgedTextTool -and $emptyTurnCount -gt 0 -and [string]$runtime.Data.state -ne 'BLOCKED'){$forceFinal=$false;$emptyTurnCount=0}
        if($mustVerify -and $toolCalls.Count -eq 0){
            $plainCommand=$content.Trim()
            if($plainCommand -notmatch '[\r\n]' -and (Test-NativeAgentVerificationCommand $plainCommand)){
                $toolCalls=@([ordered]@{function=[ordered]@{name='shell';arguments=[ordered]@{command=$plainCommand}}})
                $content=''
            }
        }
        $transcriptCalls=($toolCalls|ConvertTo-Json -Depth 30|ConvertFrom-Json)
        [void]$messages.Add((Get-NativeAgentCompactedHistoryMessage $message));[void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='assistant';Content=$content;ToolCalls=@($transcriptCalls);PromptTokens=$reply.PromptTokens;OutputTokens=$reply.OutputTokens})
        if(-not $Quiet){Write-Host '';Write-Host "    tokens: prompt $($reply.PromptTokens) - output $($reply.OutputTokens) - total $promptTotal/$outputTotal" -ForegroundColor DarkGray}
        foreach($call in $toolCalls){
            $fn=Get-NativeAgentArgument $call 'function';$name=[string](Get-NativeAgentArgument $fn 'name');$args=Get-NativeAgentArgument $fn 'arguments' @{}
            if($args -is [string]){try{$args=$args|ConvertFrom-Json}catch{$args=@{raw=$args}}}
            # Small local models sometimes use common tool aliases even when
            # the advertised schema uses our canonical names. Normalize only
            # semantics-preserving aliases; the regular shell allowlist and
            # repository path guards remain authoritative.
            $name=switch($name){
                {$_ -in @('run','run_command','execute_command')} {'shell';break}
                {$_ -in @('read','read-file')} {'read_file';break}
                default {$name}
            }
            if($name -eq 'shell'){
                $shellCommand=[string](Get-NativeAgentArgument $args 'command' '')
                if($shellCommand -match '^(.*\S)\s+2>&1\s*$'){
                    if($args -is [Collections.IDictionary]){$args['command']=$Matches[1]}else{$args.command=$Matches[1]}
                }
            }
            $signature=$name+'|'+($args|ConvertTo-Json -Depth 10 -Compress)
            $signatureCount=if($toolSignatureCounts.ContainsKey($signature)){[int]$toolSignatureCounts[$signature]+1}else{1}
            $toolSignatureCounts[$signature]=$signatureCount
            if($forceFinal){
                [void]$messages.Add([ordered]@{role='tool';content='ERROR: deterministic runtime has closed tool access; emit TASK_BLOCKED with existing evidence.'})
                [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='tool';Name=$name;Content='REJECTED: tool access closed'})
                continue
            }
            if($mustVerify -and $name -ne 'shell'){
                [void]$messages.Add([ordered]@{role='tool';content='ERROR: repeated writes require a focused test/build command before another repository edit.'})
                [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='tool';Name=$name;Content='REJECTED: verification required'})
                continue
            }
            $allowedRepairRead=$mustEdit -and $name -eq 'read_file' -and $repairReadsRemaining -gt 0
            $repairReadPath=if($allowedRepairRead){([string](Get-NativeAgentArgument $args 'path' '')).Replace('\','/').ToLowerInvariant()}else{''}
            if($allowedRepairRead -and $repairReadPath -and $repairReadPaths.ContainsKey($repairReadPath)){
                [void]$messages.Add([ordered]@{role='tool';content='ERROR: this file was already inspected during the current repair cycle. Read the failing test file/line named by the cached verification output, or make the smallest repair edit now.'})
                [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='tool';Name=$name;Content='REJECTED: duplicate repair read'})
                continue
            }
            if($mustEdit -and -not $allowedRepairRead -and $name -notin @('write_file','rewrite_file','replace_text','replace_lines')){
                $phaseViolationCount++
                $phaseReason=if([int]$runtime.Data.repairCycles -gt 0){
                    $cachedFailure=Compress-NativeAgentToolOutput ([string]$runtime.Data.lastFailure)
                    "A failed verification is captured below and is authoritative; repeating the command cannot add evidence. Use one edit tool to repair it now.`nCACHED VERIFICATION FAILURE:`n$cachedFailure"
                }else{
                    $changedNow=if(@($runtime.Data.changedFiles).Count){@($runtime.Data.changedFiles)-join ', '}else{'NONE'}
                    "The bounded investigation phase is complete. This is not a verification failure and repository access is working. Changed files: $changedNow. Use one edit tool now; if requested tests are not in that list, edit the appropriate test file."
                }
                [void]$messages.Add([ordered]@{role='tool';content="ERROR: $phaseReason"})
                [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='tool';Name=$name;Content='REJECTED: deterministic edit phase requires one repository change'})
                if($phaseViolationCount -ge 3){
                    $forceFinal=$true
                    Stop-LsdaMicroRun -Run $runtime -Reason 'model repeated a tool outside the deterministic repair phase'
                    [void]$messages.Add([ordered]@{role='user';content='Tool access is closed after three phase violations. Emit TASK_BLOCKED with the failed-verification and routing evidence.'})
                }
                continue
            }
            if(-not $Quiet){Write-Host "    [tool] $name" -ForegroundColor Cyan}
            $toolSucceeded=$false;$toolChanged=$false
            try{$toolResult=Invoke-NativeAgentTool -Name $name -Arguments $args -RepositoryRoot $RepositoryRoot -ReadOnly:$ReadOnly -AllowDependencyChanges:$AllowDependencyChanges -CommandTimeoutSeconds ([int]$hardware.commandTimeoutSeconds);$toolText=$toolResult.Output;$toolSucceeded=$true;$toolChanged=[bool]$toolResult.Changed;if(-not $Quiet){Write-Host "      OK: $($toolText -split "`n"|Select-Object -First 1)" -ForegroundColor DarkGray}}
            catch{$toolText="ERROR: $($_.Exception.Message)";if(-not $Quiet){Write-Host "      FAIL: $toolText" -ForegroundColor Yellow}}
            if($allowedRepairRead -and $toolSucceeded){
                if($repairReadPath){$repairReadPaths[$repairReadPath]=$true}
                $repairReadsRemaining--
                if($repairReadsRemaining -eq 0){[void]$messages.Add([ordered]@{role='user';content='REPAIR INSPECTION COMPLETE: the four permitted source/test inspections are consumed. Your next response must call one edit tool that directly fixes the captured test failure.'})}
            }
            # Policy/tool rejection is not engineering verification and must
            # not consume a repair cycle. Require a captured command result.
            $isVerification=$name -eq 'shell' -and (Test-NativeAgentVerificationCommand ([string](Get-NativeAgentArgument $args 'command' ''))) -and ($toolSucceeded -or $toolText -match 'Command failed with exit code')
            $isLint=$name -eq 'shell' -and (Test-NativeAgentLintCommand ([string](Get-NativeAgentArgument $args 'command' '')))
            $runtimeBlock=Add-LsdaMicroAction -Run $runtime -Name $name -Signature $signature -Succeeded $toolSucceeded -Changed $toolChanged -Failure $(if($toolSucceeded){$null}else{$toolText}) -IsVerification $isVerification -IsLint $isLint -Path ([string](Get-NativeAgentArgument $args 'path' ''))
            if($toolChanged){
                $mustEdit=$false;$investigationCalls=0;$repairReadsRemaining=0;$repairReadPaths=@{};$phaseViolationCount=0
                $toolSignatureCounts=@{};$lastToolFingerprint='';$repeatedToolCount=0
                $writePath=[string](Get-NativeAgentArgument $args 'path' '')
                if($writePath){$postEditReadPaths.Remove($writePath.Replace('\','/').ToLowerInvariant())}
                if($writePath){$writePathCounts[$writePath]=if($writePathCounts.ContainsKey($writePath)){[int]$writePathCounts[$writePath]+1}else{1}}
                if($writePath -and [int]$writePathCounts[$writePath] -ge 5){
                    $mustVerify=$true
                    [void]$messages.Add([ordered]@{role='user';content="The runtime recorded five writes to '$writePath' without verification. Do not rewrite or reread it again yet. Run one focused repository-relative verification now. Use exactly one applicable command with no cd, /repo, pipe, redirection, or chaining: Python 'python -m pytest -q'; Maven 'mvn.cmd test'; Gradle 'gradlew.bat test'; Rust 'cargo test'; Node 'npm test'; generic 'git diff --check'. Use its actual result for the next repair."})
                }
            }
            if($name -eq 'shell' -and $isVerification){
                $mustVerify=$false;$writePathCounts=@{}
                if(-not $toolSucceeded){
                    $mustEdit=$true;$repairReadsRemaining=4;$repairReadPaths=@{};$phaseViolationCount=0
                    [void]$messages.Add([ordered]@{role='user';content='FAILED VERIFICATION REPAIR PHASE: the command output above is the authoritative defect evidence. Make one direct repair edit. If the current source already matches the specification, inspect the failing test file and exact line instead; repair reads must be unique. Do not rerun verification before an edit.'})
                }
            }
            # Evidence keeps the complete response, while the next model turn
            # receives a bounded representation to avoid KV/context pollution.
            $modelToolText=Compress-NativeAgentToolOutput $toolText
            [void]$messages.Add([ordered]@{role='tool';content=$modelToolText})
            [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='tool';Name=$name;Content=$toolText})
            if(-not $ReadOnly -and $toolSucceeded -and $name -in @('read_file','list_files','search_text')){
                $investigationCalls++
                if($name -eq 'read_file'){
                    $postEditPath=[string](Get-NativeAgentArgument $args 'path' '')
                    if($postEditPath){$postEditReadPaths[$postEditPath.Replace('\','/').ToLowerInvariant()]=$true}
                    $changedPaths=@($runtime.Data.changedFiles|ForEach-Object{([string]$_).Replace('\','/').ToLowerInvariant()})
                    $hasChangedTest=@($changedPaths|Where-Object{$_ -match '(?:^|/)tests?(?:/|$)|(?:^|/)test_[^/]+\.py$|\.(?:test|spec)\.(?:js|ts|jsx|tsx)$'}).Count -gt 0
                    # A read explicitly granted inside the failed-verification
                    # repair phase is diagnostic context, not post-edit proof.
                    # It must never reopen verification before one repair edit.
                    if(-not $allowedRepairRead -and $changedPaths.Count -gt 0 -and (-not $taskRequiresTestChanges -or $hasChangedTest) -and @($changedPaths|Where-Object{-not $postEditReadPaths.ContainsKey($_)}).Count -eq 0){
                        $mustEdit=$false;$mustVerify=$true
                        [void]$messages.Add([ordered]@{role='user';content='POST-EDIT INSPECTION COMPLETE: every changed file was reread after its latest write. Do not inspect or edit again before verification. Run the focused repository test/build command now.'})
                    }
                }
                if($investigationCalls -ge 4 -and -not $mustEdit -and -not $mustVerify){
                    $mustEdit=$true
                    $changedSummary=if(@($runtime.Data.changedFiles).Count){@($runtime.Data.changedFiles)-join ', '}else{'NONE'}
                    [void]$messages.Add([ordered]@{role='user';content="INVESTIGATION BUDGET COMPLETE: four repository inspections are enough for this phase and satisfy the common two-source/two-test contract. Files already changed: $changedSummary. Until one repository change succeeds, only edit tools are available. Your next response must edit the smallest still-unmet acceptance item; when the task requests regression coverage and no changed test is listed above, edit a test file now. Do not print or explain code."})
                }
            }
            if($ReadOnly -and $toolSucceeded -and $name -eq 'read_file'){
                $readPath=[string](Get-NativeAgentArgument $args 'path' '')
                if($readPath){$readPaths[$readPath.ToLowerInvariant()]=$true}
                if($declaredReadCount -gt 0 -and $readPaths.Count -ge $declaredReadCount -and -not $forceFinal){
                    $forceFinal=$true
                    [void]$messages.Add([ordered]@{role='user';content="DECLARED INSPECTION COMPLETE: $($readPaths.Count)/$declaredReadCount unique requested files were read successfully. Tool access is now closed. Immediately emit TASK_COMPLETE with the requested factual report; do not claim BLOCKED and do not request more tools."})
                }
            }
            if($toolSucceeded -and $toolText -match '(?m)^(?:SYNTAX CHECK FAILED|TEST QUALITY FAILED):?\s*(.+)$'){
                [void]$messages.Add([ordered]@{role='user';content="POST-EDIT DIAGNOSTIC REQUIRES REPAIR: $($Matches[0]). The write itself succeeded. Make the smallest grounded edit now; do not regenerate unrelated code."})
            }
            if($toolChanged -and [string](Get-NativeAgentArgument $args 'path' '') -match '(?i)(?:^|[\\/])tests?[\\/]|(?:^|[\\/])test_[^\\/]+\.py$'){
                $acceptanceAfterWrite=Test-NativeAgentTaskAcceptance -RepositoryRoot $RepositoryRoot -Task $Task
                if(-not $acceptanceAfterWrite.Passed){[void]$messages.Add([ordered]@{role='user';content="TASK ACCEPTANCE DIAGNOSTIC: $($acceptanceAfterWrite.Reason). Repair these exact omissions with a small edit before running the full test suite."})}
            }
            if($runtimeBlock -eq 'identical action repeated without progress' -and $toolChanged){
                $runtimeBlock=$null;$mustVerify=$true
                [void]$messages.Add([ordered]@{role='user';content="REPETITIVE EDIT PRESSURE: the same changing edit was applied repeatedly. This is not an external blocker. Stop editing and run the focused repository test now so the deterministic result can drive repair."})
            }
            if($runtimeBlock -and -not $forceFinal){$forceFinal=$true;Stop-LsdaMicroRun -Run $runtime -Reason $runtimeBlock;[void]$messages.Add([ordered]@{role='user';content="The deterministic runtime stopped tool access: $runtimeBlock. Emit TASK_BLOCKED and report this evidence without claiming completion."})}
            $fingerprint=$name+'|'+(($args|ConvertTo-Json -Depth 10 -Compress))+'|'+$toolText
            if($fingerprint -eq $lastToolFingerprint -or ($toolText -eq '<no matches>' -and $lastToolFingerprint -like ($name+'|*|<no matches>'))){$repeatedToolCount++}else{$repeatedToolCount=1}
            $lastToolFingerprint=$fingerprint
            if($repeatedToolCount -eq 3){
                [void]$messages.Add([ordered]@{role='user';content='You are repeating a tool call without new evidence. Do not call that tool again with the same intent. Use the files already read, choose a different concrete tool, or finish now with TASK_COMPLETE/TASK_BLOCKED and the required factual report.'})
                if(-not $Quiet){Write-Host '      STALL: repeated tool call; corrective instruction injected' -ForegroundColor Yellow}
            }
            if($signatureCount -eq 3){
                [void]$messages.Add([ordered]@{role='user';content="The exact tool call '$name' has now repeated three times. Its arguments are stale. Do not repeat it. If the complete current file is a short placeholder, use rewrite_file with the complete desired content. Otherwise read the target region and use replace_lines or a newly grounded exact replacement. Then run the relevant tests."})
                if(-not $Quiet){Write-Host '      STALL: repeated non-consecutive tool signature; recovery instruction injected' -ForegroundColor Yellow}
            }
            if($signatureCount -ge 5 -and -not $forceFinal){
                $forceFinal=$true
                [void]$messages.Add([ordered]@{role='user';content='Tool access is closed after five identical calls. Emit TASK_BLOCKED with the repeated-call evidence; do not claim completion.'})
                if(-not $Quiet){Write-Host '      STALL CUTOFF: repeated tool signature' -ForegroundColor Yellow}
            }
            if($repeatedToolCount -ge 6 -and -not $forceFinal){
                $forceFinal=$true
                [void]$messages.Add([ordered]@{role='user';content='Tool access is now closed because repeated calls produced no evidence. Using only the evidence already collected, immediately emit TASK_COMPLETE or TASK_BLOCKED followed by the required factual FINAL RESULT report. Do not request or describe another tool call.'})
                if(-not $Quiet){Write-Host '      STALL CUTOFF: tools disabled; forcing factual final response' -ForegroundColor Yellow}
            }
        }
        if(-not $ReadOnly -and $toolCalls.Count -gt 0 -and [bool]$runtime.Data.changed){
            $runtimeDone=Test-LsdaMicroDone $runtime
            if($runtimeDone.Allowed){
                $acceptance=Test-NativeAgentTaskAcceptance -RepositoryRoot $RepositoryRoot -Task $Task
                if($acceptance.Passed){
                    $gitAcceptance=Test-NativeAgentGitAcceptance -RepositoryRoot $RepositoryRoot -Baseline $gitBaseline
                    $runtime.Data.git.final=$gitAcceptance.State;$runtime.Data.git.passed=$gitAcceptance.Passed;$runtime.Data.git.reason=$gitAcceptance.Reason;Save-LsdaMicroRun $runtime
                    if($gitAcceptance.Passed){
                        $changedList=@($runtime.Data.changedFiles|ForEach-Object{"- $_"}) -join "`n"
                        $content="TASK_COMPLETE`nFINAL RESULT: PASS`nWORKFLOW: native-agent`n`nSUMMARY`nDeterministic repository verification passed after the recorded changes.`n`nCHANGED FILES`n$changedList`n`nVERIFICATION`nRecorded test/build and required lint gates passed with ExitCode: 0.`n`nACCEPTANCE`nTask acceptance and Git safety checks passed.`n`nRISKS / NOT VERIFIED`nNONE"
                        [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='runtime-finalizer';Content='Completed immediately from verified mutation, task acceptance and Git evidence.'})
                    }
                }
            }
        }
        if($ReadOnly -and $toolCalls.Count -eq 0 -and $content -notmatch '(?i)\bTASK_(?:COMPLETE|BLOCKED)\b' -and $requiredComplianceIds.Count -gt 0){
            $normalizedReport=$content -replace '[\u2010-\u2015]','-'
            $missingComplianceIds=@($requiredComplianceIds|Where-Object{$normalizedReport -notmatch [regex]::Escape($_)})
            if($missingComplianceIds.Count -eq 0 -and $normalizedReport -match '(?i)\b(?:PASS|FAIL|PARTIAL|COMPLIANT|NON-COMPLIANT)\b' -and $normalizedReport -match '(?i)(?:evidence|доказ|строк|line\s+\d)'){
                $content="TASK_COMPLETE`nFINAL RESULT: PASS`nWORKFLOW: analysis`n`nCOMPLIANCE MATRIX`n$normalizedReport"
                [void]$messages.Add([ordered]@{role='assistant';content=$content})
                [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='runtime-finalizer';Content='Accepted complete read-only compliance evidence without requiring a model control marker.'})
            }
        }
        if(-not $ReadOnly -and $toolCalls.Count -eq 0 -and $content -notmatch '(?i)\bTASK_(?:COMPLETE|BLOCKED)\b' -and [bool]$runtime.Data.changed -and [bool]$runtime.Data.verificationPassed -and $content -match '(?im)^\s*FINAL RESULT:\s*PASS\s*$' -and $content -match '(?im)^\s*SUMMARY\s*$' -and $content -match '(?im)^\s*VERIFICATION\s*$'){
            $content="TASK_COMPLETE`n$content"
            [void]$messages.Add([ordered]@{role='assistant';content=$content})
            [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='runtime-finalizer';Content='Accepted verified mutation PASS evidence without requiring a model control marker.'})
        }
        if($content -match '(?i)\bTASK_COMPLETE\b'){
            $done=Test-LsdaMicroDone $runtime
            if($done.Allowed){
                $acceptance=Test-NativeAgentTaskAcceptance -RepositoryRoot $RepositoryRoot -Task $Task
                if(-not $acceptance.Passed){$done=[pscustomobject]@{Allowed=$false;Reason="task acceptance failed: $($acceptance.Reason)"}}
            }
            if($done.Allowed -and $Task -match '(?i)(?:add|write|create|добав|напис|созда).{0,40}(?:regression|meaningful|boundary|hidden|автотест|тест|coverage)'){
                $changedTests=@($runtime.Data.changedFiles|Where-Object{$_ -match '(?i)(?:^|[\\/])tests?[\\/]|(?:^|[\\/])test_[^\\/]+\.py$|\.(?:test|spec)\.(?:js|ts|jsx|tsx)$'})
                if($changedTests.Count -eq 0){$done=[pscustomobject]@{Allowed=$false;Reason='task requires new or updated test coverage, but no test file write was recorded'}}
            }
            if($done.Allowed){
                $gitAcceptance=Test-NativeAgentGitAcceptance -RepositoryRoot $RepositoryRoot -Baseline $gitBaseline
                $runtime.Data.git.final=$gitAcceptance.State;$runtime.Data.git.passed=$gitAcceptance.Passed;$runtime.Data.git.reason=$gitAcceptance.Reason;Save-LsdaMicroRun $runtime
                if(-not $gitAcceptance.Passed){$done=[pscustomobject]@{Allowed=$false;Reason="Git acceptance failed: $($gitAcceptance.Reason)"}}
            }
            if($done.Allowed){Set-LsdaMicroState $runtime 'DONE';$completed=$true;$final=$content;break}
            if([string]$runtime.Data.state -eq 'BLOCKED'){$completed=$false;$final="TASK_BLOCKED`nFINAL RESULT: BLOCKED`nWORKFLOW: native-agent`n`nSUMMARY`nRuntime rejected completion: $($runtime.Data.blocker).";break}
            [void]$messages.Add([ordered]@{role='user';content="Completion was rejected by the deterministic runtime: $($done.Reason). Continue with the required repository action and successful shell verification, or emit TASK_BLOCKED."})
            if(-not $Quiet){Write-Host "    DONE REJECTED: $($done.Reason)" -ForegroundColor Yellow}
        }elseif($content -match '(?i)\bTASK_BLOCKED\b'){
            $blocked=Test-LsdaMicroBlocked $runtime
            if($blocked.Allowed){$completed=$false;$final=$content;Stop-LsdaMicroRun -Run $runtime -Reason 'model reported a concrete blocker';break}
            $forceFinal=$false;$toolSignatureCounts=@{};$lastToolFingerprint='';$repeatedToolCount=0
            if(-not $ReadOnly -and [bool]$runtime.Data.changed -and -not [bool]$runtime.Data.verificationPassed){$mustEdit=$false;$repairReadsRemaining=0;$mustVerify=$true}
            $recoveryAction=if($ReadOnly){
                'Produce the requested report now; use another read only if material evidence is genuinely missing.'
            }elseif($mustVerify){
                "Tool access is open and the shell tool is available now. Verification pressure is active. Your next response must call shell with the focused repository test command (for this stack use the command named in the task, otherwise use git diff --check); do not print a command or code block."
            }else{
                'Your next response must call write_file, rewrite_file, replace_lines, or replace_text with the concrete edit; do not merely print a code block.'
            }
            [void]$messages.Add([ordered]@{role='user';content="BLOCKED was rejected by the deterministic runtime: $($blocked.Reason). $recoveryAction Then run focused verification. BLOCKED is only for an external condition supported by a failed tool result."})
            if(-not $Quiet){Write-Host "    BLOCKED REJECTED: $($blocked.Reason)" -ForegroundColor Yellow}
        }
        if($toolCalls.Count -eq 0 -and [string]::IsNullOrWhiteSpace($content)){
            $emptyTurnCount++
            [void]$messages.Add([ordered]@{role='user';content='Your last turn emitted neither text nor a tool call. Immediately perform one concrete repository tool call. If implementation is complete, run the relevant test command first; only then emit TASK_COMPLETE with evidence.'})
            if($emptyTurnCount -ge 2){$forceFinal=$true}
            if(-not $Quiet){Write-Host "    STALL: empty model turn $emptyTurnCount" -ForegroundColor Yellow}
            if($emptyTurnCount -ge 3){
                $final="TASK_BLOCKED`nFINAL RESULT: BLOCKED`nWORKFLOW: native-agent`n`nSUMMARY`nModel emitted three consecutive empty turns; wrapper stopped the run without accepting completion."
                if(-not $Quiet){Write-Host '    STALL CUTOFF: three empty turns; run blocked' -ForegroundColor Yellow}
                break
            }
        }else{$emptyTurnCount=0}
        if($toolCalls.Count -eq 0 -and -not[string]::IsNullOrWhiteSpace($content)){
            [void]$messages.Add([ordered]@{role='user';content='Continue the task. Use tools for remaining work. Finish only with TASK_COMPLETE or TASK_BLOCKED and a factual final report.'})
        }
        if($TranscriptPath){@($transcript)|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $TranscriptPath -Encoding UTF8}
    }
    if(-not $final){$final="TASK_BLOCKED`nFINAL RESULT: BLOCKED`nWORKFLOW: native-agent`n`nSUMMARY`nTurn budget exhausted before deterministic completion.";Stop-LsdaMicroRun -Run $runtime -Reason 'turn budget exhausted'}
    if($TranscriptPath){@($transcript)|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $TranscriptPath -Encoding UTF8}
    return [pscustomobject]@{Completed=$completed;FinalOutput=$final;TotalPromptTokens=$promptTotal;TotalOutputTokens=$outputTotal;Transcript=@($transcript);Messages=@($messages)}
}
