[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$beta=Get-Content -LiteralPath (Join-Path $root 'tests\VERIFY-BETA-RELIABILITY.ps1') -Raw

function NeedModule([string]$Needle,[string]$Name){
  if($module -notmatch [regex]::Escape($Needle)){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}
function NeedBeta([string]$Needle,[string]$Name){
  if($beta -notmatch [regex]::Escape($Needle)){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

NeedModule 'function Write-DeterministicComplianceFinalResult' 'wrapper compliance finalizer exists'
NeedModule 'Static evidence is never promoted to PASS' 'fallback cannot claim PASS'
NeedModule 'FINAL RESULT: PARTIAL' 'conservative compliance fallback status retained'
NeedModule 'wrapper could not extract material requirements from repository documentation' 'authoritative FAIL remains after deterministic finalizer exhaustion'
NeedBeta 'conservative compliance finalizer' 'beta regression targets current finalizer architecture'
NeedBeta 'authoritative compliance failure after finalizer exhaustion' 'beta regression retains hard-failure path'
if($beta -match [regex]::Escape('The compliance workflow did not produce the required requirements-to-code-to-tests matrix')){throw '[FAIL] stale pre-finalizer beta contract retained'}
Write-Host 'Compliance finalizer regression contract PASS' -ForegroundColor Cyan
