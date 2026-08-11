[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$skill=Get-Content (Join-Path $root 'skills\documentation-compliance.md') -Raw
function Need([string]$Name,[string]$Needle){if($module -notmatch [regex]::Escape($Needle)){throw "Missing beta reliability contract: $Name"};Write-Host "[PASS] $Name" -ForegroundColor Green}
Need 'robust git top-level detection' 'rev-parse --show-toplevel'
Need 'compliance result validator' 'function Test-AgentComplianceResult'
Need 'compliance recovery' 'function Invoke-AgentComplianceRecovery'
Need 'compliance recovery evidence' 'compliance-recovery-output.txt'
Need 'conservative compliance finalizer' 'Static evidence is never promoted to PASS'
Need 'authoritative compliance failure after finalizer exhaustion' 'wrapper could not extract material requirements from repository documentation'
Need 'quality skipped on incomplete semantic run' "'SKIPPED WITH WARNINGS'"
Need 'clean console prompt' '[Console]::ReadLine()'
Need 'guard label for non-mutating workflow' "'GUARDS'"
Need 'natural result aliases' 'ну\s+и'
if($skill -notmatch 'COMPLIANCE MATRIX'){throw 'Compliance matrix contract missing'}
if($skill -notmatch 'Do not ask the user what to inspect next'){throw 'Compliance completion contract missing'}
if($skill -notmatch 'BLOCKED is allowed only'){throw 'BLOCKED restriction missing'}
Write-Host '[PASS] strict compliance skill' -ForegroundColor Green
Write-Host 'Beta reliability verification PASS' -ForegroundColor Cyan
