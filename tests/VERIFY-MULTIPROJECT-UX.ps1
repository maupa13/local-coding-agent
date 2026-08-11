[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$i=Get-Content (Join-Path $root 'powershell\INSTALL.ps1') -Raw
$u=Get-Content (Join-Path $root 'UNINSTALL.ps1') -Raw
function Need([string]$Name,[string]$Text,[string]$Hay=$m){if(-not $Hay.Contains($Text)){throw $Name}}
Need 'global settings path' "'settings.json'"
Need 'project settings home' "'projects'"
Need 'project preference API' 'function Set-AgentProjectPreference'
Need 'project read dirs' "Set-AgentProjectPreference -RepositoryRoot `$RepositoryRoot -Name 'readDirs'"
Need 'settings command' "if (`$line -eq '/settings')"
Need 'compact model label' 'function Get-AgentCompactModelLabel'
Need 'compact prompt' "[Console]::ReadLine()"
Need 'compact QG header' 'QG✓'
Need 'full PowerShell interpreter discovery' 'function Get-AgentWindowsPowerShellPath'
Need 'generated interpreter path' 'Get-AgentIdeaRunConfigXml -InterpreterPath (Get-AgentWindowsPowerShellPath)'
Need 'project discovery' 'function Find-AgentIdeaProjects'
Need 'bulk IDEA integration' 'function Install-AgentIdeaIntegrations'
Need 'agent-idea-all' 'function agent-idea-all'
Need 'new IDEA project self-wiring' "Install-AgentIdeaIntegration -Project `$root | Out-Null"
Need '/idea all' "'^/idea\s+all(?:\s+(.+))?$'"
Need 'installer ProjectsRoot' '[string[]]$ProjectsRoot' $i
Need 'installer auto integration' 'Install-AgentIdeaIntegrations -Root $projectRoot' $i
Need 'installer standard C Projects' "'C:\Projects'" $i
Need 'package removable message' 'may be removed after a successful install' $i
Need 'installed uninstaller' "Copy-Item (Join-Path `$PackageRoot 'UNINSTALL.ps1') (Join-Path `$AgentHome 'UNINSTALL.ps1') -Force" $i
Need 'uninstall IDEA cleanup' 'ideaProjects' $u
Write-Host '[PASS] multi-project IDEA UX, compact prompt, and global/project settings separation' -ForegroundColor Green
