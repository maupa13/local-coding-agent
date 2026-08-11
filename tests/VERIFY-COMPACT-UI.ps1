[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
function RequireText([string]$Name,[string]$Needle){if(-not $m.Contains($Needle)){throw $Name}}
RequireText 'compact default missing' '$script:AgentVerboseOutput = $false'
RequireText 'captured output verbose guard missing' 'if ($ShowLiveOutput -or $script:AgentVerboseOutput) { Write-Host $line }'
RequireText '/verbose on|off missing' "'^/verbose\s+(on|off)$'"
RequireText '/log command missing' "'^/log(?:\s+(open|full))?$'"
RequireText '/log open missing' 'Start-Process explorer.exe'
RequireText 'developer execution stage missing' 'Engineering execution'
RequireText 'deterministic verification stage missing' 'Deterministic verification'
RequireText 'elapsed summary missing' 'ELAPSED:'
RequireText 'ANSI sanitizer missing' 'function Remove-AgentAnsi'
RequireText 'dumb terminal guard missing' '$env:TERM=''dumb'''
RequireText 'compact help missing' 'function Show-AgentCompactHelp'
RequireText 'deterministic status missing' 'function Show-AgentLastStatus'
RequireText 'diff quality signals missing' 'function Get-DiffQualitySignals'
RequireText 'disabled test guard missing' '@Disabled'
RequireText 'secret-looking file guard missing' 'sensitive/secret-looking file changed'
RequireText 'missing regression coverage warning missing' 'no test/spec file changed'
Write-Host '[PASS] compact terminal UI and diff quality hardening' -ForegroundColor Green
