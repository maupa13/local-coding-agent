[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$qualify=Get-Content -LiteralPath (Join-Path $root 'powershell\QUALIFY-RELEASE.ps1') -Raw
$verify=Get-Content -LiteralPath (Join-Path $root 'powershell\VERIFY-PACKAGE.ps1') -Raw

function Need([string]$Text,[string]$Pattern,[string]$Name){
  if($Text -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

if($qualify -match 'Join-Path \$root ''logs'''){throw '[FAIL] qualification logs are still written inside package root'}
Write-Host '[PASS] qualification logs are outside package root' -ForegroundColor Green
Need $qualify 'LOCALAPPDATA' 'qualification prefers LocalAppData diagnostic root'
Need $qualify 'STEP-\$safeName\.stdout\.log' 'per-step stdout logging'
Need $qualify 'STEP-\$safeName\.stderr\.log' 'per-step stderr logging'
Need $verify 'logs\|evidence\|results\|test-results' 'package source scan excludes transient runtime directories'
Need $verify 'hardcoded user profile in distributable source' 'package profile failure prints evidence sample'
Write-Host 'Log isolation regression PASS' -ForegroundColor Cyan
