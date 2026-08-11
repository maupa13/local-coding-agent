$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$analysis=Get-Content (Join-Path $root 'workflows\analyze.md') -Raw
$skill=Get-Content (Join-Path $root 'skills\documentation-compliance.md') -Raw
$required=@(
 'function Get-AgentRepositoryInventory',
 'function Write-AgentDeveloperDiscovery',
 'wrapper-generated context, not user instructions',
 "`$cnArgs += @('--rule',`$inventoryRule)",
 'function Write-AgentProgressFromLine',
 'function Get-AgentWorkingTreeFingerprint',
 'function Write-AgentStructuredResult',
 'function Get-AgentRunFileDelta',
 'function Test-AgentComplianceTask',
 'Сопоставление требований: документация',
 '-DeveloperProgress',
 'verification commands changed the working tree',
 'rerunning checks once'
)
foreach($n in $required){if($module -notlike "*$n*"){throw "Missing Engineering Quality contract: $n"};Write-Host "[PASS] $n" -ForegroundColor Green}
if($analysis -notmatch 'compliance analysis'){throw 'analyze workflow lacks compliance analysis contract'}
if($skill -notmatch 'COMPLIANCE MATRIX'){throw 'documentation compliance skill lacks matrix contract'}
Write-Host '[PASS] Engineering Quality / developer progress / compliance / fresh verification' -ForegroundColor Green
