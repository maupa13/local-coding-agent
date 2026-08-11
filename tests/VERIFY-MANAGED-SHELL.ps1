[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$checks=@{
  'managed slash shell'='function Start-AgentShell'
  'raw TUI escape hatch'='function agent-tui'
  'distribution self-target guard'='function Test-IsAgentDistributionPath'
  'project pinning'='Use agent -Project'
  'captured cn output'='function Invoke-CnCaptured'
  'semantic final parser'='function Get-FinalResultStatus'
  'automatic recovery'='function Invoke-AgentRecovery'
  'deterministic fallback'='function Write-DeterministicFallbackResult'
  'semantic evidence'='SEMANTIC RESULT:'
}
foreach($entry in $checks.GetEnumerator()){
  if($module -notmatch [regex]::Escape($entry.Value)){ throw "Missing $($entry.Key): $($entry.Value)" }
  Write-Host "[PASS] $($entry.Key)"
}
