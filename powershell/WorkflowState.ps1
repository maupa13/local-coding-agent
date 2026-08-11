<#
.SYNOPSIS
Deterministic work-item lifecycle used by delivery workflows.
.DESCRIPTION
The model may propose work, but it cannot invent or skip transitions. Every
transition is loaded from config/work-item-workflows.json and its required
evidence gates must be supplied by the wrapper.
#>
function Get-AgentWorkflowDefinition {
    [CmdletBinding()]
    param([string]$Path)
    if (-not $Path) {
        $moduleDir = Split-Path -Parent $PSCommandPath
        $sourceCandidate = Join-Path (Split-Path -Parent $moduleDir) 'config\work-item-workflows.json'
        $installedCandidate = Join-Path $moduleDir 'work-item-workflows.json'
        $Path = if (Test-Path -LiteralPath $sourceCandidate) { $sourceCandidate } else { $installedCandidate }
    }
    if (-not (Test-Path -LiteralPath $Path)) { throw "Workflow definition not found: $Path" }
    $definition = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ([int]$definition.schemaVersion -ne 1) { throw "Unsupported workflow schema: $($definition.schemaVersion)" }
    return $definition
}

function New-AgentWorkItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('feature','bugfix','refactor','docs')][string]$Type,
        [Parameter(Mandatory)][string]$Summary,
        [string]$Id = ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    )
    [pscustomobject][ordered]@{
        id=$Id; type=$Type; summary=$Summary; status='Backlog'; resolution=$null
        createdAt=(Get-Date).ToString('o'); updatedAt=(Get-Date).ToString('o'); history=@()
    }
}

function Move-AgentWorkItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$WorkItem,
        [Parameter(Mandatory)][string]$Transition,
        [hashtable]$Evidence=@{},
        [string]$DefinitionPath
    )
    $definition=Get-AgentWorkflowDefinition -Path $DefinitionPath
    if ([string]$WorkItem.status -in @($definition.terminalStatuses)) { throw "Terminal work item cannot transition from $($WorkItem.status)" }
    $candidates=@($definition.transitions|Where-Object{
        [string]$_.name -eq $Transition -and ([string]$_.from -eq [string]$WorkItem.status -or [string]$_.from -eq '*')
    })
    if ($candidates.Count -ne 1) { throw "Transition '$Transition' is not allowed from '$($WorkItem.status)'" }
    $edge=$candidates[0]
    $scheme=@($definition.schemes.PSObject.Properties[[string]$WorkItem.type].Value)
    if ([string]$edge.to -notin $scheme -and [string]$edge.to -notin @('Blocked','Rejected')) {
        throw "Status '$($edge.to)' is not part of the '$($WorkItem.type)' workflow scheme"
    }
    foreach($gate in @($edge.requires)) {
        if (-not $Evidence.ContainsKey([string]$gate) -or -not [bool]$Evidence[[string]$gate]) {
            throw "Transition '$Transition' requires evidence gate '$gate'"
        }
    }
    $from=[string]$WorkItem.status
    $WorkItem.status=[string]$edge.to
    $WorkItem.updatedAt=(Get-Date).ToString('o')
    if($WorkItem.status -in @($definition.terminalStatuses)){$WorkItem.resolution=$WorkItem.status}
    $event=[pscustomobject][ordered]@{transition=$Transition;from=$from;to=$WorkItem.status;at=$WorkItem.updatedAt;evidence=@($edge.requires)}
    $WorkItem.history=@($WorkItem.history)+@($event)
    return $WorkItem
}
