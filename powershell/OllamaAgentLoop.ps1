Set-StrictMode -Version Latest

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
    if($Command -match '(?i)(?:&&|\|\||;|`|\$\(|Invoke-Expression|\biex\b|Remove-Item|\brm\b|\bdel\b|\brmdir\b|git\s+(?:reset|clean|checkout|restore|commit|push|rebase|merge)|shutdown|Restart-Computer|Stop-Computer)'){return $false}
    return $Command -match '^(?i)\s*(?:git\s+(?:status|diff|log|show)|(?:\.\\)?gradlew(?:\.bat)?\s+|mvn(?:\.cmd)?\s+|npm(?:\.cmd)?\s+(?:test|run\s+|--prefix\s+)|node\s+--test|python(?:\.exe)?\s+-m\s+(?:pytest|unittest)|pytest\s+|cargo\s+(?:check|test|build|clippy|fmt)|dotnet\s+(?:test|build)|go\s+test|powershell(?:\.exe)?\s+-NoProfile\s+-File\s+\.\\tests\\)'
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
        return 'SYNTAX CHECK PASS (node --check)'
    }
    if($extension -in @('.ps1','.psm1','.psd1')){
        $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
        if(@($errors).Count){return "SYNTAX CHECK FAILED (PowerShell parser):`n$((@($errors)|ForEach-Object{$_.Message}) -join "`n")"}
        return 'SYNTAX CHECK PASS (PowerShell parser)'
    }
    if($extension -eq '.json'){
        try{Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json|Out-Null;return 'SYNTAX CHECK PASS (JSON parser)'}catch{return "SYNTAX CHECK FAILED (JSON parser): $($_.Exception.Message)"}
    }
    return ''
}

function Compress-NativeAgentToolOutput {
    param([string]$Text,[int]$MaximumCharacters=6000)
    if($null -eq $Text -or $Text.Length -le $MaximumCharacters){return $Text}
    $head=[math]::Floor($MaximumCharacters*0.3);$tail=$MaximumCharacters-$head
    return $Text.Substring(0,$head)+"`n... <tool output compacted; full output is preserved in transcript> ...`n"+$Text.Substring($Text.Length-$tail)
}

function Invoke-NativeAgentTool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Arguments,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [switch]$ReadOnly,[switch]$AllowDependencyChanges
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
            if($last -ge $start){$rows=for($i=$start;$i -le $last;$i++){('{0,5}: {1}' -f $i,$all[$i-1])};$output=$rows -join "`n"}
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
            if(Test-Path -LiteralPath $path){throw 'write_file creates new files only; use replace_text or replace_lines for an existing file'}
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
                throw "replace_text expected exactly one match, found $count. Current file:`n$($numbered -join "`n")"
            }
            $updated=$text.Replace($old,$new);Set-Content -LiteralPath $path -Encoding UTF8 -NoNewline -Value $updated;$changed=$true;$output="Replaced one occurrence in $relative"
            $syntax=Get-NativeAgentSyntaxDiagnostic $path;if($syntax){$output+="`n$syntax"}
        }
        'shell' {
            if($ReadOnly -and ([string](Get-NativeAgentArgument $Arguments 'command')) -notmatch '^(?i)\s*git\s+(?:status|diff|log|show)'){throw 'Only read-only Git shell commands are enabled in read-only mode'}
            $command=[string](Get-NativeAgentArgument $Arguments 'command');if(-not(Test-NativeAgentShellCommand $command)){throw "Shell command is outside the managed allowlist: $command"}
            # Resolve global executables before spawning a clean child shell. This
            # avoids malformed user PATH entries changing which program is executed.
            if($command -match '^\s*(git|npm|node|mvn|cargo|dotnet|go|pytest|python)(?:\.cmd|\.exe)?\s+(.+)$'){
                $toolName=$matches[1];$toolArgs=$matches[2]
                $resolvedTool=Get-Command $toolName,$($toolName+'.cmd'),$($toolName+'.exe') -ErrorAction SilentlyContinue|Where-Object{$_.CommandType -eq 'Application'}|Select-Object -First 1
                if($resolvedTool){$escapedTool=$resolvedTool.Source.Replace("'","''");$command="& '$escapedTool' $toolArgs"}
            }
            $timeout=[math]::Min(300,[math]::Max(1,[int](Get-NativeAgentArgument $Arguments 'timeout_seconds' 120)))
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
    foreach($d in $defs){[ordered]@{type='function';function=[ordered]@{name=$d[0];description=$d[1];parameters=[ordered]@{type='object';properties=($d[2]|ConvertFrom-Json);required=$d[3]}}}}
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
            if($chunk.message){
                $piece=[string](Get-NativeAgentArgument $chunk.message 'content' '')
                if($piece){[void]$text.Append($piece);if($OnChunk){& $OnChunk $piece}}
                foreach($tc in @(Get-NativeAgentArgument $chunk.message 'tool_calls' @())){[void]$toolCalls.Add($tc)}
            }
            if($chunk.done){$promptTokens=[int]$chunk.prompt_eval_count;$outputTokens=[int]$chunk.eval_count;$loadMs=[math]::Round(([double]$chunk.load_duration/1000000),0);$totalMs=[math]::Round(([double]$chunk.total_duration/1000000),0)}
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
        [scriptblock]$ChatInvoker=${function:Invoke-OllamaNativeChat},[int]$MaxTurns=40,[switch]$ReadOnly,[switch]$Quiet,
        [string]$TranscriptPath,[switch]$AllowDependencyChanges
    )
    $messages=New-Object Collections.ArrayList
    [void]$messages.Add([ordered]@{role='system';content=$SystemPrompt})
    [void]$messages.Add([ordered]@{role='user';content=$Task})
    $transcript=New-Object Collections.ArrayList;$promptTotal=0;$outputTotal=0;$completed=$false;$final='';$lastToolFingerprint='';$repeatedToolCount=0;$emptyTurnCount=0;$toolSignatureCounts=@{};$forceFinal=$false
    for($turn=1;$turn -le $MaxTurns;$turn++){
        if(-not $Quiet){Write-Host "  [agent] turn $turn/$MaxTurns - $Model" -ForegroundColor DarkGray}
        # Tool execution needs short observable decisions. Disabling extended
        # thinking prevents Qwen from consuming the entire turn without
        # emitting content or a tool call.
        $request=[ordered]@{model=$Model;stream=$false;think=$false;messages=@($messages);options=@{temperature=0.1;num_ctx=16384;num_predict=2048};keep_alive='15m'}
        if(-not $forceFinal){$request.tools=@(Get-NativeOllamaTools)}
        $reply=& $ChatInvoker $request {param($chunk)if(-not $Quiet){Write-Host $chunk -NoNewline}}
        $promptTotal+=[int]$reply.PromptTokens;$outputTotal+=[int]$reply.OutputTokens
        $message=$reply.Message;$content=[string](Get-NativeAgentArgument $message 'content' '')
        $toolCalls=@(Get-NativeAgentArgument $message 'tool_calls' @())
        [void]$messages.Add($message);[void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='assistant';Content=$content;ToolCalls=$toolCalls;PromptTokens=$reply.PromptTokens;OutputTokens=$reply.OutputTokens})
        if(-not $Quiet){Write-Host '';Write-Host "    tokens: prompt $($reply.PromptTokens) - output $($reply.OutputTokens) - total $promptTotal/$outputTotal" -ForegroundColor DarkGray}
        foreach($call in $toolCalls){
            $fn=Get-NativeAgentArgument $call 'function';$name=[string](Get-NativeAgentArgument $fn 'name');$args=Get-NativeAgentArgument $fn 'arguments' @{}
            if($args -is [string]){try{$args=$args|ConvertFrom-Json}catch{$args=@{raw=$args}}}
            $signature=$name+'|'+($args|ConvertTo-Json -Depth 10 -Compress)
            $signatureCount=if($toolSignatureCounts.ContainsKey($signature)){[int]$toolSignatureCounts[$signature]+1}else{1}
            $toolSignatureCounts[$signature]=$signatureCount
            if(-not $Quiet){Write-Host "    [tool] $name" -ForegroundColor Cyan}
            try{$toolResult=Invoke-NativeAgentTool -Name $name -Arguments $args -RepositoryRoot $RepositoryRoot -ReadOnly:$ReadOnly -AllowDependencyChanges:$AllowDependencyChanges;$toolText=$toolResult.Output;if(-not $Quiet){Write-Host "      OK: $($toolText -split "`n"|Select-Object -First 1)" -ForegroundColor DarkGray}}
            catch{$toolText="ERROR: $($_.Exception.Message)";if(-not $Quiet){Write-Host "      FAIL: $toolText" -ForegroundColor Yellow}}
            # Evidence keeps the complete response, while the next model turn
            # receives a bounded representation to avoid KV/context pollution.
            $modelToolText=Compress-NativeAgentToolOutput $toolText
            [void]$messages.Add([ordered]@{role='tool';content=$modelToolText})
            [void]$transcript.Add([pscustomobject]@{Turn=$turn;Role='tool';Name=$name;Content=$toolText})
            $fingerprint=$name+'|'+(($args|ConvertTo-Json -Depth 10 -Compress))+'|'+$toolText
            if($fingerprint -eq $lastToolFingerprint -or ($toolText -eq '<no matches>' -and $lastToolFingerprint -like ($name+'|*|<no matches>'))){$repeatedToolCount++}else{$repeatedToolCount=1}
            $lastToolFingerprint=$fingerprint
            if($repeatedToolCount -eq 3){
                [void]$messages.Add([ordered]@{role='user';content='You are repeating a tool call without new evidence. Do not call that tool again with the same intent. Use the files already read, choose a different concrete tool, or finish now with TASK_COMPLETE/TASK_BLOCKED and the required factual report.'})
                if(-not $Quiet){Write-Host '      STALL: repeated tool call; corrective instruction injected' -ForegroundColor Yellow}
            }
            if($signatureCount -eq 3){
                [void]$messages.Add([ordered]@{role='user';content="The exact tool call '$name' has now repeated three times. Its arguments are stale. Do not repeat it. Read the complete current file, then use replace_lines or a newly grounded exact replacement, and run the relevant tests."})
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
        if($content -match '(?i)\bTASK_COMPLETE\b' -or $content -match '(?i)\bTASK_BLOCKED\b'){$completed=$content -match '(?i)\bTASK_COMPLETE\b';$final=$content;break}
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
    if($TranscriptPath){@($transcript)|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $TranscriptPath -Encoding UTF8}
    return [pscustomobject]@{Completed=$completed;FinalOutput=$final;TotalPromptTokens=$promptTotal;TotalOutputTokens=$outputTotal;Transcript=@($transcript);Messages=@($messages)}
}
