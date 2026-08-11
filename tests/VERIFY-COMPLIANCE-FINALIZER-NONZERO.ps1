[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

function Need([string]$Pattern,[string]$Name){
  if($module -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

if($module -match 'Write-DeterministicComplianceFinalResult[\s\S]{0,800}if\(\$ExitCode -ne 0\)\{return \$null\}'){
  throw '[FAIL] compliance finalizer is still disabled by non-zero model exit'
}
Write-Host '[PASS] non-zero model exit does not disable compliance finalizer' -ForegroundColor Green
Need 'Continue CLI exit code: \$\(if\(\$ExitCode -eq 0\)' 'non-zero model exit is preserved in evidence'
Need 'incomplete/failed model summary' 'finalizer explicitly tolerates failed model summary'
Write-Host 'Compliance finalizer nonzero-exit regression PASS' -ForegroundColor Cyan
