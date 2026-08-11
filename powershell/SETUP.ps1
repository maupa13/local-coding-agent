[CmdletBinding()]
param(
  [switch]$LoginContinue,
  [switch]$InstallRecommendedModels
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host '== Local Coding Agent bootstrap ==' -ForegroundColor Cyan
Write-Host "Source: $root" -ForegroundColor DarkGray

function Need([string]$Name,[string]$Hint){
  if(-not(Get-Command $Name -ErrorAction SilentlyContinue)){throw "Missing '$Name'. $Hint"}
}
Need 'git' 'Install Git for Windows.'
Need 'node' 'Install Node.js 20+.'
Need 'npm' 'Install npm/Node.js.'
if(-not(Get-Command cn -ErrorAction SilentlyContinue)){
  Write-Host '[setup] Continue CLI missing; installing through npm...' -ForegroundColor Cyan
  npm install -g @continuedev/cli
  if($LASTEXITCODE -ne 0){throw 'Failed to install @continuedev/cli.'}
}

try{$null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5}
catch{throw "Ollama is not reachable at http://127.0.0.1:11434. Start your Ollama service/container first. $($_.Exception.Message)"}

if($LoginContinue){
  Write-Host '[setup] Starting Continue first-run login...' -ForegroundColor Cyan
  cn login
  if($LASTEXITCODE -ne 0){throw "Continue login failed with exit code $LASTEXITCODE."}
}

& (Join-Path $root 'tests\TEST-CONTINUE-PREFLIGHT.ps1')
if($LASTEXITCODE -ne 0){
  Write-Host ''
  Write-Host 'Bootstrap stopped before installation.' -ForegroundColor Red
  Write-Host 'If the diagnostic asks for Continue authentication, run:' -ForegroundColor Yellow
  Write-Host '  .\SETUP.ps1 -LoginContinue' -ForegroundColor Cyan
  exit $LASTEXITCODE
}

Write-Host '[setup] Selecting a model that actually works with Continue file tools...' -ForegroundColor Cyan
& (Join-Path $root 'tests\SELECT-WORKING-TOOL-MODEL.ps1')
if($LASTEXITCODE -ne 0){
  Write-Host ''
  Write-Host 'Bootstrap stopped: no installed model passed the real Continue Edit/Write smoke.' -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host '[setup] Final real tool smoke with selected model...' -ForegroundColor Cyan
& (Join-Path $root 'tests\RUN-CONTINUE-TOOL-SMOKE.ps1')
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

$installArgs=@()
if($InstallRecommendedModels){$installArgs+='-InstallRecommendedModels'}
& (Join-Path $root 'INSTALL.ps1') @installArgs
exit $LASTEXITCODE
