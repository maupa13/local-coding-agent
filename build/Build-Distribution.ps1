<#
.SYNOPSIS
Builds a self-contained Local Coding Agent distribution ZIP.
.DESCRIPTION
Validates source, runs deterministic tests, stages only distributable files,
imports the staged module in Windows PowerShell, and creates a versioned ZIP.
#>
[CmdletBinding()]
param([switch]$Clean,[switch]$SkipTests)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$artifactRoot=Join-Path $root 'artifacts'
$stage=Join-Path $artifactRoot ("local-coding-agent-$version")
$zip=$stage+'.zip'

if($Clean){
    # Targets are fixed children of artifacts; never accept caller-supplied delete paths.
    foreach($target in @($stage,$zip)){if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Recurse -Force}}
}
if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
New-Item -ItemType Directory -Force -Path $stage|Out-Null

$windowsPowerShell=Join-Path $PSHOME 'powershell.exe';if(-not(Test-Path -LiteralPath $windowsPowerShell)){$windowsPowerShell=(Get-Command powershell.exe -ErrorAction Stop).Source}
function Invoke-BuildGate([string]$ScriptPath){
    & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
    if($LASTEXITCODE -ne 0){throw "Build gate failed ($LASTEXITCODE): $ScriptPath"}
}
Invoke-BuildGate (Join-Path $root 'powershell\VERIFY-PACKAGE.ps1')
if(-not $SkipTests){
    Invoke-BuildGate (Join-Path $root 'tests\RUN-ALL.ps1')
}

foreach($directory in @('config','docs','integrations','powershell','skills','workflows')){
    Copy-Item -LiteralPath (Join-Path $root $directory) -Destination (Join-Path $stage $directory) -Recurse
}
foreach($file in @('VERSION','SETUP.cmd','SANDBOX-QUALIFICATION.json')){Copy-Item -LiteralPath (Join-Path $root $file) -Destination $stage}
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'tests')|Out-Null
foreach($file in @('RUN-ALL.ps1','RUN-STARTUP-SMOKE.ps1','RUN-LIVE-E2E.ps1','RUN-MODEL-EVAL.ps1','TEST-MATRIX.json','SCENARIO-MATRIX.json','MODEL-EVAL-MATRIX.json')){
    $source=Join-Path $root ('tests\'+$file);if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $stage 'tests')}
}
if(Test-Path -LiteralPath (Join-Path $root 'tests\evals')){Copy-Item -LiteralPath (Join-Path $root 'tests\evals') -Destination (Join-Path $stage 'tests\evals') -Recurse}

$manifest=Join-Path $stage 'powershell\LocalCodingAgent.psd1'
Test-ModuleManifest -Path $manifest -ErrorAction Stop|Out-Null
& $windowsPowerShell -NoLogo -NoProfile -Command "Import-Module '$manifest' -Force -DisableNameChecking; if(-not(Get-Command Start-LocalCodingAgent -ErrorAction SilentlyContinue)){exit 2}"
if($LASTEXITCODE -ne 0){throw "Staged module import failed with exit code $LASTEXITCODE"}
if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
$hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash
@{version=$version;sha256=$hash;builtAt=(Get-Date).ToString('o');module='powershell/LocalCodingAgent.psd1'}|ConvertTo-Json|Set-Content -Encoding UTF8 (Join-Path $artifactRoot 'build-manifest.json')
Write-Host "[PASS] Distribution: $zip" -ForegroundColor Green
Write-Host "[PASS] SHA256: $hash" -ForegroundColor Green
