[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $PSScriptRoot
$CandidateVersion = (Get-Content -LiteralPath (Join-Path $PackageRoot 'VERSION') -Raw).Trim()
$ContinueHome = Join-Path $env:USERPROFILE '.continue'
$RuntimeVersionPath = Join-Path $ContinueHome 'local-coding-agent\VERSION'
if(-not(Test-Path -LiteralPath $RuntimeVersionPath)){ throw "Installed runtime VERSION is missing. Candidate $CandidateVersion is not installed; run INSTALL.ps1 successfully first." }
$InstalledVersion = (Get-Content -LiteralPath $RuntimeVersionPath -Raw).Trim()
if($InstalledVersion -ne $CandidateVersion){ throw "Installed runtime version '$InstalledVersion' does not match candidate '$CandidateVersion'. INSTALL.ps1 did not complete for this candidate." }
$ModulePath = Join-Path $ContinueHome 'local-coding-agent\LocalCodingAgent.psd1'
if (-not (Test-Path $ModulePath)) { throw "Installed module not found: $ModulePath. Run INSTALL.ps1 first." }
# Remove stale legacy functions from the current shell, then import managed module globally.
$legacy = @(
  'agent','agent-idea','agent-idea-all','agent-fast','agent-tui','agent-ask','agent-team','agent-plan','agent-auto','agent-resume','agent-check','agent-build','agent-one',
  'agent-analyze','agent-feature','agent-bugfix','agent-hotfix','agent-refactor','agent-test','agent-review','agent-result',
  'agent-release','agent-release-feature','agent-release-bugfix','agent-release-hotfix',
  'agent-docs','agent-business','agent-architecture','agent-migration','agent-performance','agent-security',
  'agent-deliver-feature','agent-deliver-bugfix','agent-deliver-hotfix','agent-init','agent-help','agent-doctor','agent-workflows'
)
foreach ($name in $legacy) {
  Remove-Item "Alias:$name" -Force -ErrorAction SilentlyContinue
  Remove-Item "Function:\global:$name" -Force -ErrorAction SilentlyContinue
}
Remove-Module LocalCodingAgent -Force -ErrorAction SilentlyContinue
Import-Module $ModulePath -Global -Force -DisableNameChecking
Set-Alias -Name agent -Value Start-LocalCodingAgent -Scope Global -Force
$resolvedAgent=Get-Command agent -ErrorAction Stop
if($resolvedAgent.CommandType -ne 'Alias' -or $resolvedAgent.Definition -ne 'Start-LocalCodingAgent'){throw "Activation failed: agent resolves to $($resolvedAgent.CommandType) $($resolvedAgent.Definition), not managed launcher."}
Write-Host "Local Coding Agent $CandidateVersion activated in this PowerShell." -ForegroundColor Green
Write-Host 'Run: agent -Project <your-real-project>; type / for product commands. Plain text is auto-routed.' -ForegroundColor Cyan
