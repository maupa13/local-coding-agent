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

Need 'function Get-AgentComplianceRequirements' 'deterministic requirement extraction'
Need 'function Get-AgentComplianceEvidence' 'repository-grounded compliance evidence'
Need 'function Write-DeterministicComplianceFinalResult' 'wrapper compliance finalizer'
Need 'COMPLIANCE MATRIX' 'wrapper emits compliance matrix'
Need 'Static evidence is never promoted to PASS' 'compliance fallback is conservative'
Need 'function Write-DeterministicWorkflowFinalResult' 'generic wrapper provisional finalizer'
Need 'wrapperCanPromote' 'verified wrapper promotion contract'
Need 'deterministic verification passed' 'promotion requires deterministic verification'
Need '\$review\.Status -in @\(''PASS'',''WARN''\)' 'promotion rejects failed independent review'
Write-Host 'Wrapper finalizer contract PASS' -ForegroundColor Cyan
