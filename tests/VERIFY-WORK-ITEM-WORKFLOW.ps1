[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\WorkflowState.ps1')
$definition=Join-Path $root 'config\work-item-workflows.json'

function Assert-Throws([scriptblock]$Action,[string]$Pattern){
    try{& $Action;throw 'Expected operation to fail'}catch{if($_.Exception.Message -eq 'Expected operation to fail' -or $_.Exception.Message -notmatch $Pattern){throw}}
}

$item=New-AgentWorkItem -Type feature -Summary 'verified delivery'
Move-AgentWorkItem $item triage -DefinitionPath $definition|Out-Null
Assert-Throws {Move-AgentWorkItem $item accept -DefinitionPath $definition|Out-Null} 'requires evidence'
Move-AgentWorkItem $item accept @{requirements=$true} $definition|Out-Null
Move-AgentWorkItem $item start @{} $definition|Out-Null
Assert-Throws {Move-AgentWorkItem $item submit @{changes=$true} $definition|Out-Null} "tests"
Move-AgentWorkItem $item submit @{changes=$true;tests=$true} $definition|Out-Null
Move-AgentWorkItem $item verify @{deterministicChecks=$true} $definition|Out-Null
Move-AgentWorkItem $item approve @{review=$true;evidence=$true} $definition|Out-Null
Assert-Throws {Move-AgentWorkItem $item ship @{build=$true;evidence=$true} $definition|Out-Null} 'hiddenEval'
Move-AgentWorkItem $item ship @{build=$true;hiddenEval=$true;evidence=$true} $definition|Out-Null
if($item.status -ne 'Released' -or $item.resolution -ne 'Released' -or $item.history.Count -ne 7){throw 'successful lifecycle was not recorded'}
Assert-Throws {Move-AgentWorkItem $item block @{blocker=$true} $definition|Out-Null} 'Terminal work item'

$failed=New-AgentWorkItem -Type bugfix -Summary 'verification return path'
Move-AgentWorkItem $failed triage @{} $definition|Out-Null
Move-AgentWorkItem $failed accept @{requirements=$true} $definition|Out-Null
Move-AgentWorkItem $failed start @{} $definition|Out-Null
Move-AgentWorkItem $failed submit @{changes=$true;tests=$true} $definition|Out-Null
Move-AgentWorkItem $failed fix-verification @{verificationFailed=$true} $definition|Out-Null
if($failed.status -ne 'Implementation'){throw 'failed verification did not return work to implementation'}

Write-Host '[PASS] work-item statuses, transitions, gates, resolution, and rework path' -ForegroundColor Green
