[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$p=Get-Content (Join-Path $root 'config\permissions.yaml') -Raw

function Require([string]$Name,[bool]$Condition){if(-not $Condition){throw $Name}}

Require 'quality engine workflow selector missing' ($m -match 'function Test-WorkflowUsesQualityEngine')
Require 'deterministic quality checks missing' ($m -match 'function Invoke-DeterministicQualityChecks')
Require 'independent review missing' ($m -match 'function Invoke-IndependentQualityReview')
Require 'quality score missing' ($m -match 'QUALITY SCORE:')
Require 'quality checks not capped' ($m -match 'Select-Object -First 4')
Require 'requirements bundle missing' ($m -match 'function New-AgentRequirementsBundle')
Require 'absolute/local requirements path resolver missing' ($m -match 'function Resolve-RequirementLocalPath')
Require 'exact URL ingestion missing' ($m -match 'Invoke-WebRequest -Uri \$candidate')
Require 'requirements source rule not injected' ($m -match '--rule'',\$sourceBundle\.Path')
Require 'Bash should be automatic in installed permission profile' ($p -match '(?m)^- Bash\(\*\)$')
Require 'Bash ask prompts should be disabled' ($p -match '(?m)^ask:\s*\[\]\s*$')
Require 'destructive git push is not excluded' ($p -match 'Bash\(git push\*\)')
Require 'dependency update is not excluded' ($p -match 'Bash\(cargo update\*\)')
Require 'managed CLI does not broadly allow Bash' ($m -match "'--allow','Bash'")
Require 'read-only workflows must exclude Bash' ($m -match "'--exclude','Bash'")
Require 'managed Fetch should be excluded until research layer exists' ($m -match "'--exclude','Fetch'")
Require 'dependency restore safety net missing' ($m -match 'function Restore-UnauthorizedDependencyChanges')
Require 'protected pre-run snapshots missing' ($m -match 'function Save-DependencySensitiveBackups')
Require 'diff quality function missing' ($m -match 'function Get-DiffQualitySignals')
Require 'test-disable diff guard missing' ($m -match 'changed diff appears to disable or skip tests')
Require 'quality warnings not persisted' ($m -match 'quality-report.txt')
Write-Host '[PASS] alpha.8 quality engine / requirements ingestion / low-prompt permissions' -ForegroundColor Green
