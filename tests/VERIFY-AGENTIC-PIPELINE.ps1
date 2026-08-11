[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
$activate=Get-Content -LiteralPath (Join-Path $root 'ACTIVATE.ps1') -Raw
$install=Get-Content -LiteralPath (Join-Path $root 'INSTALL.ps1') -Raw
function Need([string]$Name,[string]$Needle,[string]$Text=$module){if(-not $Text.Contains($Needle)){throw "[FAIL] $Name"}}

Need 'team pipeline function' 'function Invoke-AgentTeamPipeline'
Need 'planner uses fast model' "Invoke-AgentWorkflow -Workflow 'analyze' -DisplayWorkflow 'analysis'"
Need 'planner fast flag' '-Fast -ReadOnly -Headless'
Need 'reviewer fast flag' '-Fast -ReadOnly -Headless'
Need 'fast review config supported' "if (`$Role -eq 'review' -and `$Fast)"
Need 'team command function' 'function agent-team'
Need 'planner role' "role='planner'"
Need 'implementer role' "role='implementer'"
Need 'tester role' "role='tester'"
Need 'reviewer role' "role='reviewer'"
Need 'fresh planner workflow' "Invoke-AgentWorkflow -Workflow 'analyze'"
Need 'fresh reviewer workflow' "Invoke-AgentWorkflow -Workflow 'review'"
Need 'pipeline stops on blocking phase' 'if($phaseStatus -in @(''BLOCKED'',''FAIL''))'
Need 'pipeline state persistence' 'teamPipeline'
Need 'continue accepts answer' "'^/continue(?:\s+(.*))?$'"
Need 'answer is attached to original task' 'User clarification:'
Need 'shell team parser' "'^/team(?:\s+(.*))?$'"
Need 'activation team cleanup' "'agent-team'" $activate
Need 'installer team activation' "'agent-team'" $install
Need 'team function exported' "'agent-team'"

Write-Host '[PASS] agentic pipeline roles, stop policy, persistence, and resumable clarification contract' -ForegroundColor Green
Write-Host 'Agentic pipeline regression PASS' -ForegroundColor Cyan
