[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module = Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$installer = Get-Content (Join-Path $root 'powershell\INSTALL.ps1') -Raw
$launcher = Get-Content (Join-Path $root 'integrations\IDEA-LAUNCH.ps1') -Raw
$helper = Get-Content (Join-Path $root 'IDEA-INTEGRATE.ps1') -Raw
$needles = @(
    'function Install-AgentIdeaIntegration',
    'function Show-AgentIdeaIntegration',
    'function Remove-AgentIdeaIntegration',
    'function agent-idea',
    'function agent-idea-all',
    'function Install-AgentIdeaIntegrations',
    'function Get-AgentWindowsPowerShellPath',
    '^/idea(?:\s+(install|status|remove))?$',
    '.idea\runConfigurations\Local_Coding_Agent.xml',
    'type="ShConfigurationType"',
    'EXECUTE_IN_TERMINAL',
    '$USER_HOME$/.continue/local-coding-agent/IDEA-LAUNCH.ps1',
    '$PROJECT_DIR$',
    '__INTERPRETER__'
)
foreach ($needle in $needles) {
    if ($module -notlike "*$needle*") { throw "Missing IDEA integration contract: $needle" }
}
if ($installer -notmatch '\[string\]\$IdeaProject') { throw 'Installer -IdeaProject option missing' }
if ($installer -notmatch '\[string\[\]\]\$ProjectsRoot') { throw 'Installer -ProjectsRoot option missing' }
if ($installer -notlike "*integrations\IDEA-LAUNCH.ps1*") { throw 'Installer does not deploy IDEA launcher' }
if ($installer -notlike '*Install-AgentIdeaIntegration -Project $IdeaProject*') { throw 'Installer does not integrate requested IDEA project' }
if ($launcher -notlike '*Start-LocalCodingAgent -Project $Project*') { throw 'IDEA launcher does not start managed agent' }
if ($launcher -match 'C:\\Users\\[^\\]+') { throw 'IDEA launcher contains hardcoded Windows user' }
if ($helper -notlike '*Install-AgentIdeaIntegration*' -or $helper -notlike '*Remove-AgentIdeaIntegration*') { throw 'Standalone IDEA integration helper incomplete' }
Write-Host '[PASS] IntelliJ IDEA project Run configuration integration' -ForegroundColor Green
