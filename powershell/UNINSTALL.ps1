[CmdletBinding()]
param([switch]$RestoreLatestBackup)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ContinueHome = Join-Path $env:USERPROFILE '.continue'
$AgentHome = Join-Path $ContinueHome 'local-coding-agent'
$profilePath = $PROFILE.CurrentUserAllHosts
$start = '# >>> LOCAL CODING AGENT V2 >>>'
$end = '# <<< LOCAL CODING AGENT V2 <<<'

function Remove-AgentProfileBlock {
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw
        $pattern = '(?s)' + [regex]::Escape($start) + '.*?' + [regex]::Escape($end) + '\s*'
        [regex]::Replace($content,$pattern,'') | Set-Content -Encoding UTF8 $profilePath
    }
}

if (-not $RestoreLatestBackup) {
    Remove-AgentProfileBlock
    $settingsPath=Join-Path $AgentHome 'settings.json'
    if(Test-Path -LiteralPath $settingsPath){
        try{
            $settings=Get-Content -LiteralPath $settingsPath -Raw|ConvertFrom-Json
            $prop=$settings.PSObject.Properties['ideaProjects']
            if($prop){foreach($project in @($prop.Value)){
                $cfg=Join-Path ([string]$project) '.idea\runConfigurations\Local_Coding_Agent.xml'
                if(Test-Path -LiteralPath $cfg){$text=Get-Content -LiteralPath $cfg -Raw;if($text -match 'local-coding-agent/IDEA-LAUNCH\.ps1'){Remove-Item -LiteralPath $cfg -Force -ErrorAction SilentlyContinue}}
            }}
        }catch{Write-Host "[WARN] Could not clean all IDEA project launchers: $($_.Exception.Message)" -ForegroundColor Yellow}
    }
    if (Test-Path $AgentHome) { Remove-Item $AgentHome -Recurse -Force }
    Write-Host 'Local Coding Agent runtime removed. Existing Continue configs were left untouched.' -ForegroundColor Green
    Write-Host 'Open a new PowerShell.'
    exit 0
}

$backupRoot = Join-Path $ContinueHome 'backup'
$b = Get-ChildItem $backupRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'local-coding-agent-backup-*' -or $_.Name -like 'local-coding-agent-v2-*' } |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $b) { throw 'No Local Coding Agent backup found.' }

# Remove current managed runtime/config before restoring the snapshot.
if (Test-Path $AgentHome) { Remove-Item $AgentHome -Recurse -Force }
foreach ($name in @('config.yaml','config-agent.yaml','config-agent-fast.yaml','permissions.yaml','config.json')) {
    $dst = Join-Path $ContinueHome $name
    if (Test-Path $dst) { Remove-Item $dst -Force }
    $src = Join-Path $b.FullName $name
    if (Test-Path $src) { Copy-Item $src $dst -Force }
}
foreach ($dirName in @('rules','prompts')) {
    $dstDir = Join-Path $ContinueHome $dirName
    if (Test-Path $dstDir) { Remove-Item $dstDir -Recurse -Force }
    $srcDir = Join-Path $b.FullName $dirName
    if (Test-Path $srcDir) { Copy-Item $srcDir $dstDir -Recurse -Force }
}

$runtimeBackup = Join-Path $b.FullName 'local-coding-agent'
if (Test-Path $runtimeBackup) { Copy-Item $runtimeBackup $AgentHome -Recurse -Force }

$profileBackup = Join-Path $b.FullName 'powershell-profile.ps1'
if (Test-Path $profileBackup) {
    $profileDir = Split-Path -Parent $profilePath
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    Copy-Item $profileBackup $profilePath -Force
} else {
    Remove-AgentProfileBlock
}

Write-Host "Restored backup: $($b.FullName)" -ForegroundColor Green
Write-Host 'Open a new PowerShell.'
