[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
function Need([string]$Name,[string]$Text){if(-not $m.Contains($Text)){throw $Name}}
Need '/model command' "'^/model(?:\s+(.*))?$'"
Need '/plan mode shorthand' "'^/(code|plan|debug|explain)`$'"
Need 'bare budget value guard' 'Did you mean /budget $line'
Need 'model role runtime' 'function Get-AgentRoleModel'
Need 'dynamic model config' 'function New-AgentRuntimeModelConfig'
Need 'tool-call qualification' 'Test-OllamaToolCalling $Model'
Need 'review model config' "Get-AgentEffectiveConfig -Role 'review'"
Need '/fast toggle' "'^/fast(?:\s+(on|off))?$'"
Need '/ask command' "'^/ask(?:\s+(.*))?$'"
Need 'quick side lane' 'function Invoke-AgentQuickAsk'
Need 'second terminal quick ask' 'function agent-ask'
Need '/permissions command' "'^/permissions(?:\s+(project|trusted|safe|ask|readonly))?$'"
Need 'Continue ask policy' "'--ask','Edit','--ask','MultiEdit','--ask','Write','--ask','Bash'"
Need '/add-read-dir' 'sandbox-add-read-dir'
Need '/settings command' "if (`$line -eq '/settings')"
Need 'project persisted read dirs' "Set-AgentProjectPreference -RepositoryRoot `$RepositoryRoot -Name 'readDirs'"
Need '/deliver alias' "'deliver'='deliver-feature'"
Need 'plain text router' 'function Resolve-AgentIntent'
Need 'plain text route marker' 'routed → /$name'
Need 'readonly permission block' 'Current permissions are readonly'
$activate=Get-Content (Join-Path $root 'ACTIVATE.ps1') -Raw
if($activate -notmatch 'agent-ask'){throw 'ACTIVATE missing agent-ask cleanup'}
if($activate -notmatch 'Alias:\$name'){throw 'ACTIVATE does not remove stale aliases'}
$install=Get-Content (Join-Path $root 'INSTALL.ps1') -Raw
if($install -notmatch '/model setup/install, /fast, /ask, /permissions, /add-read-dir'){throw 'installer product controls summary missing'}
Write-Host '[PASS] product CLI, model roles, quick ask, permissions and auto-routing' -ForegroundColor Green
