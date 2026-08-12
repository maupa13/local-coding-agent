[CmdletBinding()]
param(
    [switch]$SkipIdeConfig,
    [switch]$SkipProfile,
    [switch]$Force,
    [switch]$InstallRecommendedModels,
    [switch]$InstallIdeConfig,
    [string]$IdeaProject,
    [string[]]$ProjectsRoot,
    [switch]$SkipIdeaAutoIntegration
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
$ContinueHome = Join-Path $env:USERPROFILE '.continue'
$AgentHome = Join-Path $ContinueHome 'local-coding-agent'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = Join-Path $ContinueHome "backup\local-coding-agent-backup-$stamp"

Write-Host "== Local Coding Agent $Version installer ==" -ForegroundColor Cyan

# Mandatory full package verification. Installation must never proceed after a
# VERIFY-PACKAGE failure. Run verification in a child Windows PowerShell process
# so VERIFY-PACKAGE.ps1 can use exit codes without terminating this installer.
Write-Host '[preflight] Running full package verification...' -ForegroundColor DarkGray
$verifyScript = Join-Path $PackageRoot 'powershell\VERIFY-PACKAGE.ps1'
$windowsPowerShell = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path $windowsPowerShell)) {
    $windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
}
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $verifyScript
if ($LASTEXITCODE -ne 0) {
    throw "Full package verification failed with exit code $LASTEXITCODE. Nothing was installed."
}
Write-Host '[PASS] Full package verification' -ForegroundColor Green

$actualFolder = Split-Path -Leaf $PackageRoot
Write-Host "[INFO] Development source folder: $actualFolder" -ForegroundColor DarkGray
New-Item -ItemType Directory -Force -Path $ContinueHome,$Backup | Out-Null

if (-not (Get-Command cn -ErrorAction SilentlyContinue)) { throw "Required command 'cn' is not available in PATH." }
$cnVersion = (& cn --version 2>&1 | Out-String).Trim()
Write-Host "Continue CLI: $cnVersion"
try { $tags = Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5 }
catch { throw "Ollama is not reachable at http://127.0.0.1:11434. Start Ollama first. $($_.Exception.Message)" }

function Invoke-OllamaPullProgress([string]$Model) {
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromHours(3)
    $request = $null
    $response = $null
    $stream = $null
    $reader = $null
    try {
        $request = New-Object System.Net.Http.HttpRequestMessage -ArgumentList ([System.Net.Http.HttpMethod]::Post,'http://127.0.0.1:11434/api/pull')
        $payload = @{ model=$Model; stream=$true } | ConvertTo-Json -Compress
        $request.Content = New-Object System.Net.Http.StringContent -ArgumentList ($payload,[System.Text.Encoding]::UTF8,'application/json')
        $response = $client.SendAsync($request,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) { throw "Ollama pull HTTP $([int]$response.StatusCode) $($response.ReasonPhrase)" }
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $reader = New-Object System.IO.StreamReader($stream)
        $lastPercent = -1
        $lastPrinted = -10
        $lastStatus = ''
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            $errorProp = $obj.PSObject.Properties['error']
            if ($errorProp -and $errorProp.Value) { throw [string]$errorProp.Value }
            $statusProp = $obj.PSObject.Properties['status']
            $status = if ($statusProp) { [string]$statusProp.Value } else { '' }
            $totalProp = $obj.PSObject.Properties['total']
            $completedProp = $obj.PSObject.Properties['completed']
            if ($totalProp -and $completedProp -and [double]$totalProp.Value -gt 0) {
                $percent = [Math]::Min(100,[Math]::Max(0,[int]([double]$completedProp.Value * 100.0 / [double]$totalProp.Value)))
                if ($percent -ne $lastPercent) {
                    Write-Progress -Activity "Installing $Model" -Status "$status $percent%" -PercentComplete $percent
                    $lastPercent = $percent
                }
                if ($percent -ge ($lastPrinted + 10) -or $percent -eq 100) {
                    Write-Host ("  {0,3}%  {1}" -f $percent,$status) -ForegroundColor DarkGray
                    $lastPrinted = $percent
                }
            } elseif ($status -and $status -ne $lastStatus) {
                Write-Host "  $status" -ForegroundColor DarkGray
                $lastStatus = $status
            }
        }
        Write-Progress -Activity "Installing $Model" -Completed
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($response) { $response.Dispose() }
        if ($request) { $request.Dispose() }
        if ($client) { $client.Dispose() }
    }
}

$installedNames = @($tags.models | ForEach-Object { $_.name })
function Normalize-ModelName([string]$Name) {
    return (($Name.Trim()) -replace ':latest$','').ToLowerInvariant()
}
function Has-Model([string]$Name) {
    $wanted = Normalize-ModelName $Name
    foreach ($installed in $installedNames) {
        $actual = Normalize-ModelName ([string]$installed)
        if ($actual -eq $wanted -or $actual.StartsWith($wanted + ':')) { return $true }
    }
    return $false
}
$primary = 'qwen3:8b'
if($InstallRecommendedModels){
    foreach($model in @($primary)){
        if(Has-Model $model){Write-Host "[PASS] $model already installed" -ForegroundColor Green;continue}
        Write-Host "Installing $model through Ollama API..." -ForegroundColor Cyan
        Invoke-OllamaPullProgress $model
        $tags=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10
        $installedNames=@($tags.models|ForEach-Object{$_.name})
        if(-not(Has-Model $model)){throw "Model pull finished but model is still unavailable: $model"}
        Write-Host "[PASS] $model installed" -ForegroundColor Green
    }
}
if (-not (Has-Model $primary)) {
    if (-not $Force) { throw "Primary model '$primary' is not installed. Install it first or rerun INSTALL.ps1 -Force to install config anyway." }
    Write-Host "[WARN] Primary model missing: $primary" -ForegroundColor Yellow
}
foreach ($optional in @('qwen3.5:4b','qwen2.5-coder:1.5b','nomic-embed-text:latest')) {
    if (-not (Has-Model $optional)) { Write-Host "[WARN] Optional model missing: $optional" -ForegroundColor Yellow }
}

# Backup every location this installer may replace or quarantine.
$touched = @('config.yaml','config-agent.yaml','config-agent-fast.yaml','permissions.yaml','config.json')
foreach ($name in $touched) {
    $src = Join-Path $ContinueHome $name
    if (Test-Path $src) { Copy-Item $src (Join-Path $Backup $name) -Force }
}
if (Test-Path $AgentHome) { Copy-Item $AgentHome (Join-Path $Backup 'local-coding-agent') -Recurse -Force -ErrorAction SilentlyContinue }
foreach ($dirName in @('rules','prompts')) {
    $srcDir = Join-Path $ContinueHome $dirName
    if (Test-Path $srcDir) { Copy-Item $srcDir (Join-Path $Backup $dirName) -Recurse -Force }
}

# Global legacy rules/prompts can be auto-applied by Continue and contaminate every task.
foreach ($dirName in @('rules','prompts')) {
    $srcDir = Join-Path $ContinueHome $dirName
    if (Test-Path $srcDir) {
        $legacyDir = Join-Path $ContinueHome ("$dirName.legacy-$stamp")
        Move-Item $srcDir $legacyDir -Force
        Write-Host "Previous $dirName moved to: $legacyDir"
    }
}

Copy-Item (Join-Path $PackageRoot 'config\config-agent.yaml') (Join-Path $ContinueHome 'config-agent.yaml') -Force
Copy-Item (Join-Path $PackageRoot 'config\config-agent-fast.yaml') (Join-Path $ContinueHome 'config-agent-fast.yaml') -Force
Copy-Item (Join-Path $PackageRoot 'config\permissions.yaml') (Join-Path $ContinueHome 'permissions.yaml') -Force
if ($InstallIdeConfig -and -not $SkipIdeConfig) { Copy-Item (Join-Path $PackageRoot 'config\config.yaml') (Join-Path $ContinueHome 'config.yaml') -Force }
elseif (-not $SkipIdeConfig) { Write-Host '[INFO] Global Continue/IDE config left unchanged. Use -InstallIdeConfig only if you want Local Coding Agent workflows inside direct Continue/IDE.' -ForegroundColor DarkGray }

$legacy = Join-Path $ContinueHome 'config.json'
if (($InstallIdeConfig -and -not $SkipIdeConfig) -and (Test-Path $legacy)) {
    $renamed = Join-Path $ContinueHome "config.json.legacy-$stamp"
    Move-Item $legacy $renamed -Force
    Write-Host "Legacy config.json moved to: $renamed"
}

New-Item -ItemType Directory -Force -Path $AgentHome,(Join-Path $AgentHome 'workflows'),(Join-Path $AgentHome 'skills'),(Join-Path $AgentHome 'evidence'),(Join-Path $AgentHome 'projects') | Out-Null
Copy-Item (Join-Path $PackageRoot 'workflows\*.md') (Join-Path $AgentHome 'workflows') -Force
Copy-Item (Join-Path $PackageRoot 'skills\*.md') (Join-Path $AgentHome 'skills') -Force
Copy-Item (Join-Path $PackageRoot 'powershell\LocalCodingAgent.psm1') (Join-Path $AgentHome 'LocalCodingAgent.psm1') -Force
# Install the manifest beside the implementation. Consumers import the manifest
# so private helpers cannot accidentally become part of the supported API.
Copy-Item (Join-Path $PackageRoot 'powershell\LocalCodingAgent.psd1') (Join-Path $AgentHome 'LocalCodingAgent.psd1') -Force
Copy-Item (Join-Path $PackageRoot 'powershell\OllamaAgentLoop.ps1') (Join-Path $AgentHome 'OllamaAgentLoop.ps1') -Force
Copy-Item (Join-Path $PackageRoot 'powershell\MicroRuntime.ps1') (Join-Path $AgentHome 'MicroRuntime.ps1') -Force
Copy-Item (Join-Path $PackageRoot 'powershell\WorkflowState.ps1') (Join-Path $AgentHome 'WorkflowState.ps1') -Force
Copy-Item (Join-Path $PackageRoot 'powershell\ArtifactAnalysis.ps1') (Join-Path $AgentHome 'ArtifactAnalysis.ps1') -Force
Copy-Item (Join-Path $PackageRoot 'config\work-item-workflows.json') (Join-Path $AgentHome 'work-item-workflows.json') -Force
Copy-Item (Join-Path $PackageRoot 'integrations\IDEA-LAUNCH.ps1') (Join-Path $AgentHome 'IDEA-LAUNCH.ps1') -Force
Copy-Item (Join-Path $PackageRoot 'powershell\UNINSTALL.ps1') (Join-Path $AgentHome 'UNINSTALL.ps1') -Force
Copy-Item (Join-Path $PackageRoot 'workflows\catalog.json') (Join-Path $AgentHome 'catalog.json') -Force
Copy-Item (Join-Path $PackageRoot 'VERSION') (Join-Path $AgentHome 'VERSION') -Force
@{
    version = $Version
    installedAt = (Get-Date).ToString('o')
    backup = $Backup
    package = $PackageRoot
    continueCli = $cnVersion
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $AgentHome 'install.json')

if (-not $SkipProfile) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path -Parent $profilePath
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    if (Test-Path $profilePath) { Copy-Item $profilePath (Join-Path $Backup 'powershell-profile.ps1') -Force }
    $content = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { '' }
    $start = '# >>> LOCAL CODING AGENT V2 >>>'
    $end = '# <<< LOCAL CODING AGENT V2 <<<'
    $pattern = '(?s)' + [regex]::Escape($start) + '.*?' + [regex]::Escape($end) + '\s*'
    $content = [regex]::Replace($content,$pattern,'')
    $module = (Join-Path $AgentHome 'LocalCodingAgent.psd1').Replace("'","''")
    $block = @"
$start
`$legacyAgentFunctions = @('agent','agent-idea','agent-idea-all','agent-fast','agent-tui','agent-ask','agent-team','agent-plan','agent-auto','agent-resume','agent-check','agent-build','agent-one','agent-analyze','agent-feature','agent-bugfix','agent-hotfix','agent-refactor','agent-test','agent-review','agent-result','agent-release','agent-release-feature','agent-release-bugfix','agent-release-hotfix','agent-docs','agent-business','agent-architecture','agent-migration','agent-performance','agent-security','agent-deliver-feature','agent-deliver-bugfix','agent-deliver-hotfix','agent-init','agent-help','agent-doctor','agent-workflows')
foreach (`$name in `$legacyAgentFunctions) { Remove-Item "Alias:`$name" -Force -ErrorAction SilentlyContinue; Remove-Item "Function:\global:`$name" -Force -ErrorAction SilentlyContinue }
Remove-Module LocalCodingAgent -Force -ErrorAction SilentlyContinue
Import-Module '$module' -Global -Force -DisableNameChecking
Set-Alias -Name agent -Value Start-LocalCodingAgent -Scope Global -Force
$end
"@
    ($content.TrimEnd() + "`r`n`r`n" + $block + "`r`n") | Set-Content -Encoding UTF8 $profilePath
    Write-Host "PowerShell profile updated: $profilePath"
}

Write-Host "Backup: $Backup" -ForegroundColor DarkGray
Write-Host "Installation complete: $Version" -ForegroundColor Green
Write-Host ''
try {
    & (Join-Path $PackageRoot 'powershell\ACTIVATE.ps1')
    $agentCmd=Get-Command agent -ErrorAction Stop
    if($agentCmd.CommandType -ne 'Alias' -or $agentCmd.Definition -ne 'Start-LocalCodingAgent'){throw "agent launcher collision: $($agentCmd.CommandType) $($agentCmd.Definition)"}
    Write-Host '[PASS] Managed agent launcher owns the agent command.' -ForegroundColor Green
    Write-Host '[PASS] New agent commands activated in this PowerShell.' -ForegroundColor Green
} catch {
    Write-Host "[WARN] Same-shell activation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host 'Fallback: . .\ACTIVATE.ps1'
}
Write-Host ''

try {
    Import-Module (Join-Path $AgentHome 'LocalCodingAgent.psd1') -Global -Force -DisableNameChecking
    if($IdeaProject){Install-AgentIdeaIntegration -Project $IdeaProject | Out-Null}
    if(-not $SkipIdeaAutoIntegration){
        $roots=@()
        if($ProjectsRoot){$roots+=@($ProjectsRoot)}else{
            foreach($candidate in @('C:\Projects',(Join-Path $env:USERPROFILE 'IdeaProjects'),(Join-Path $env:USERPROFILE 'Projects'))){if(Test-Path -LiteralPath $candidate -PathType Container){$roots+=$candidate}}
        }
        foreach($projectRoot in @($roots|Select-Object -Unique)){
            Write-Host "[IDEA] scanning projects: $projectRoot" -ForegroundColor Cyan
            Install-AgentIdeaIntegrations -Root $projectRoot -MaxDepth 4 | Out-Null
        }
    }
} catch {
    Write-Host "[WARN] Core installation succeeded, but IDEA auto-integration failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host 'Retry later: agent-idea-all -Root C:\Projects' -ForegroundColor DarkGray
}

Write-Host 'Next:'
Write-Host '  1. agent-doctor -Deep'
Write-Host '  2. agent -Project "C:\path\to\REAL-project"'
Write-Host '     IDEA projects under C:\Projects / ~/IdeaProjects / ~/Projects are auto-integrated unless skipped.'
Write-Host '  3. type / for product commands, or just write the task'
Write-Host '  4. /deliver <goal + docs\spec.md>'
Write-Host ''
Write-Host 'Managed mode guarantees:'
Write-Host '  - one repository per workflow run'
Write-Host '  - native Ollama tool loop with visible actions, exact tokens and persisted transcript'
Write-Host '  - FINAL RESULT validation + automatic recovery'
Write-Host '  - dependency firewall + command anchoring by default'
Write-Host '  - project-first coding permissions (broad project coding; destructive/system classes excluded)'
Write-Host '  - explicit local/URL documentation ingestion before implementation'
Write-Host '  - lightweight Quality Engine: deterministic checks + independent review + score'
Write-Host '  - /model setup/install, /fast, /ask, /permissions, /add-read-dir product controls'
Write-Host '  - plain-text intent routing with /deliver as the default implementation alias'
Write-Host '  - IntelliJ IDEA one-click Run configuration with multi-project auto-integration'
Write-Host "  - package source: $PackageRoot (may be removed after a successful install)" -ForegroundColor DarkGray
Write-Host "  - installed runtime: $AgentHome" -ForegroundColor DarkGray
Write-Host '  - raw Continue TUI remains available as agent-tui'
