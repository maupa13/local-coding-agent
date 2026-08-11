[CmdletBinding()]
param(
    [string]$Project = (Get-Location).Path,
    [ValidateSet('install','status','remove','all')][string]$Action = 'install',
    [string]$Root,
    [ValidateRange(1,8)][int]$MaxDepth = 4
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $env:USERPROFILE '.continue\local-coding-agent\LocalCodingAgent.psd1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "Installed Local Coding Agent module was not found: $modulePath. Run INSTALL.ps1 first."
}
Remove-Module LocalCodingAgent -Force -ErrorAction SilentlyContinue
Import-Module $modulePath -Global -Force -DisableNameChecking
switch ($Action) {
    'install' { Install-AgentIdeaIntegration -Project $Project }
    'status'  { Show-AgentIdeaIntegration -Project $Project }
    'remove'  { Remove-AgentIdeaIntegration -Project $Project }
    'all'     { $scanRoot=if($Root){$Root}else{$Project}; Install-AgentIdeaIntegrations -Root $scanRoot -MaxDepth $MaxDepth }
}
