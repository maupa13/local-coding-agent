[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Project
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $env:USERPROFILE '.continue\local-coding-agent\LocalCodingAgent.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw "Local Coding Agent is not installed: $modulePath"
}
Remove-Module LocalCodingAgent -Force -ErrorAction SilentlyContinue
Import-Module $modulePath -Global -Force -DisableNameChecking
Start-LocalCodingAgent -Project $Project
