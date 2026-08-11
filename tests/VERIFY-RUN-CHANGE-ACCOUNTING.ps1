[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

foreach($needle in @(
  'function Get-AgentWorkingFileState',
  'function Get-AgentRunFileDelta',
  'beforeWorkingFiles = Get-AgentWorkingFileState',
  'AgentChanged=',
  'PreExisting=',
  'AGENT CHANGED FILES:',
  'PRE-EXISTING CHANGES:'
)){
  if($m -notmatch [regex]::Escape($needle)){throw "[FAIL] missing change-accounting contract: $needle"}
}
if($m -notmatch 'elseif\(-not \$normallyChanges\)\{''FAIL''\}'){
  throw '[FAIL] read-only workflow without a valid semantic answer is not fail-closed'
}
Write-Host '[PASS] pre-existing changes are separated from files changed during the run' -ForegroundColor Green
Write-Host '[PASS] incomplete read-only analysis is FAIL, not pseudo-PARTIAL' -ForegroundColor Green
Write-Host 'Run change accounting regression PASS' -ForegroundColor Cyan
