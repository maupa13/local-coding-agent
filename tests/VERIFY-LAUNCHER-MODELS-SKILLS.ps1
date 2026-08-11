[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$a=Get-Content (Join-Path $root 'ACTIVATE.ps1') -Raw
$i=Get-Content (Join-Path $root 'INSTALL.ps1') -Raw
function Need([string]$Name,[string]$Text,[string]$Hay=$m){if(-not $Hay.Contains($Text)){throw $Name}}
Need 'Ollama API base' 'function Get-AgentOllamaApiBase'
Need 'Ollama pull installer' 'function Install-AgentOllamaModel'
Need '/model setup' 'if ($arg -eq ''setup'')'
Need '/model install parser' "if (`$arg -match '^install\s+(.+)$')"
Need '/model install action' 'Install-AgentOllamaModel $Matches[1]'
Need 'official fast default support' 'qwen3.5:4b'
Need 'quality-first review fallback' "return (Get-AgentRoleModel 'work')"
Need 'workflow skills runtime' 'function Get-AgentWorkflowSkillPaths'
Need 'skills passed as rules' 'Get-AgentWorkflowSkillPaths $Workflow'
Need 'activation alias cleanup' 'Remove-Item "Alias:$name"' $a
Need 'managed launcher function' 'function Start-LocalCodingAgent'
Need 'activation launcher alias' 'Set-Alias -Name agent -Value Start-LocalCodingAgent -Scope Global -Force' $a
Need 'installer alias cleanup' 'Remove-Item "Alias:`$name"' $i
Need 'installer managed alias' 'Set-Alias -Name agent -Value Start-LocalCodingAgent -Scope Global -Force' $i
Need 'installer model switch' 'InstallRecommendedModels' $i
Need 'installer full package verify' 'VERIFY-PACKAGE.ps1' $i
Need 'installer blocks on verification failure' 'Full package verification failed' $i
Need 'streamed Ollama pull progress' 'Invoke-OllamaPullProgress' $i
Need 'runtime streamed Ollama pull progress' 'function Invoke-AgentOllamaPullProgress' $m
Need 'IDE config opt-in' 'InstallIdeConfig' $i
Need 'managed config does not require host Ollama CLI' "Required command 'cn'" $i
foreach($f in @('spec-driven-feature.md','systematic-debugging.md','verification-before-completion.md')){if(-not(Test-Path (Join-Path $root "skills\$f"))){throw "missing skill $f"}}
Write-Host '[PASS] launcher precedence, Docker-transparent Ollama model management and workflow skills' -ForegroundColor Green
