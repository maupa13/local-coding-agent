<#
.SYNOPSIS
Minimal deterministic lifecycle for one-user native agent runs.
.DESCRIPTION
The model may request completion, but only this runtime can persist DONE. State is
written after every relevant action so an interrupted run can be inspected or
resumed without trusting conversation history.
#>

function Write-LsdaMicroJsonAtomic {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)]$Value)
    $parent=Split-Path -Parent $Path
    if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{
        $Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $temporary -Encoding UTF8
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }finally{Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
}

function New-LsdaMicroRun {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$RunDirectory,
        [switch]$ReadOnly,
        [int]$MaxTurns=15,[int]$MaxToolCalls=30,[int]$MaxShellCalls=10,
        [int]$MaxRepairCycles=2,[int]$MaxNoProgressActions=5,[int]$MaxSameActionRepeats=3,
        [int]$MaxTokens=50000
    )
    $path=Join-Path $RunDirectory 'run.json'
    if(Test-Path -LiteralPath $path){
        try{
            $saved=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
            if([string]$saved.repositoryRoot -eq $RepositoryRoot -and [string]$saved.state -notin @('DONE','BLOCKED')){
                $saved.state='RECOVERING';$saved.updatedAt=(Get-Date).ToString('o')
                Write-LsdaMicroJsonAtomic -Path $path -Value $saved
                return [pscustomobject]@{Path=$path;Data=$saved;LastAction=$null;SameActionRepeats=0;NoProgressActions=0}
            }
        }catch{}
    }
    $now=(Get-Date).ToString('o')
    $data=[pscustomobject][ordered]@{
        schemaVersion=1;runId=(Split-Path $RunDirectory -Leaf);repositoryRoot=$RepositoryRoot
        state='INVESTIGATE';readOnly=[bool]$ReadOnly;createdAt=$now;updatedAt=$now
        turns=0;toolCalls=0;shellCalls=0;writeCalls=0;repairCycles=0
        promptTokens=0;outputTokens=0;changed=$false;changedFiles=@();verificationPassed=$false
        lastFailure=$null;blocker=$null
        limits=[pscustomobject]@{maxTurns=$MaxTurns;maxToolCalls=$MaxToolCalls;maxShellCalls=$MaxShellCalls;maxRepairCycles=$MaxRepairCycles;maxNoProgressActions=$MaxNoProgressActions;maxSameActionRepeats=$MaxSameActionRepeats;maxTokens=$MaxTokens}
    }
    Write-LsdaMicroJsonAtomic -Path $path -Value $data
    [pscustomobject]@{Path=$path;Data=$data;LastAction=$null;SameActionRepeats=0;NoProgressActions=0}
}

function Save-LsdaMicroRun {
    param([Parameter(Mandatory)]$Run)
    $Run.Data.updatedAt=(Get-Date).ToString('o')
    Write-LsdaMicroJsonAtomic -Path $Run.Path -Value $Run.Data
}

function Set-LsdaMicroState {
    param([Parameter(Mandatory)]$Run,[Parameter(Mandatory)][ValidateSet('INVESTIGATE','IMPLEMENT','VERIFY','REPAIR','DONE','BLOCKED','RECOVERING')][string]$State)
    $from=[string]$Run.Data.state
    $allowed=@{
        INVESTIGATE=@('IMPLEMENT','VERIFY','DONE','BLOCKED');RECOVERING=@('INVESTIGATE','IMPLEMENT','VERIFY','REPAIR','BLOCKED')
        IMPLEMENT=@('IMPLEMENT','VERIFY','BLOCKED');VERIFY=@('IMPLEMENT','REPAIR','DONE','BLOCKED')
        REPAIR=@('IMPLEMENT','VERIFY','BLOCKED');DONE=@();BLOCKED=@()
    }
    if($State -ne $from -and $allowed[$from] -notcontains $State){throw "Illegal micro-runtime transition: $from -> $State"}
    $Run.Data.state=$State;Save-LsdaMicroRun $Run
    if($State -in @('DONE','BLOCKED')){Write-LsdaMicroArtifacts $Run}
}

function Write-LsdaMicroArtifacts {
    param([Parameter(Mandatory)]$Run)
    $directory=Split-Path -Parent $Run.Path
    $changes=[pscustomobject][ordered]@{changed=[bool]$Run.Data.changed;files=@($Run.Data.changedFiles);writeCalls=[int]$Run.Data.writeCalls}
    $verification=[pscustomobject][ordered]@{passed=[bool]$Run.Data.verificationPassed;shellCalls=[int]$Run.Data.shellCalls;repairCycles=[int]$Run.Data.repairCycles;lastFailure=$Run.Data.lastFailure}
    Write-LsdaMicroJsonAtomic -Path (Join-Path $directory 'changes.json') -Value $changes
    Write-LsdaMicroJsonAtomic -Path (Join-Path $directory 'verification.json') -Value $verification
    $files=if(@($Run.Data.changedFiles).Count){@($Run.Data.changedFiles)|ForEach-Object{"- $_"}}else{@('- NONE')}
    @("# LSDA run result","","Status: $($Run.Data.state)","","Changed files:")+$files+@("","Verification: $(if($Run.Data.verificationPassed){'PASS'}else{'NOT PASSED'})","Blocker: $(if($Run.Data.blocker){$Run.Data.blocker}else{'NONE'})")|Set-Content -LiteralPath (Join-Path $directory 'result.md') -Encoding UTF8
}

function Add-LsdaMicroTurn {
    param([Parameter(Mandatory)]$Run,[int]$PromptTokens,[int]$OutputTokens)
    $Run.Data.turns=[int]$Run.Data.turns+1
    $Run.Data.promptTokens=[int]$Run.Data.promptTokens+$PromptTokens
    $Run.Data.outputTokens=[int]$Run.Data.outputTokens+$OutputTokens
    Save-LsdaMicroRun $Run
    $total=[int]$Run.Data.promptTokens+[int]$Run.Data.outputTokens
    if([int]$Run.Data.turns -gt [int]$Run.Data.limits.maxTurns){return 'turn budget exhausted'}
    if($total -gt [int]$Run.Data.limits.maxTokens){return 'token budget exhausted'}
    return $null
}

function Add-LsdaMicroAction {
    param(
        [Parameter(Mandatory)]$Run,[Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Signature,[bool]$Succeeded,[bool]$Changed,[string]$Failure,[bool]$IsVerification,[string]$Path
    )
    $Run.Data.toolCalls=[int]$Run.Data.toolCalls+1
    if($Name -eq 'shell'){$Run.Data.shellCalls=[int]$Run.Data.shellCalls+1}
    if($Changed){
        $Run.Data.writeCalls=[int]$Run.Data.writeCalls+1;$Run.Data.changed=$true;$Run.Data.verificationPassed=$false
        if($Path -and @($Run.Data.changedFiles) -notcontains $Path){$Run.Data.changedFiles=@($Run.Data.changedFiles)+@($Path)}
        $Run.NoProgressActions=0;Set-LsdaMicroState $Run 'IMPLEMENT'
    }
    elseif($Name -eq 'shell' -and $IsVerification){$Run.NoProgressActions=0;Set-LsdaMicroState $Run 'VERIFY'}
    else{$Run.NoProgressActions++}

    if($Signature -eq $Run.LastAction){$Run.SameActionRepeats++}else{$Run.LastAction=$Signature;$Run.SameActionRepeats=1}
    if($Name -eq 'shell' -and $IsVerification){
        if($Succeeded){$Run.Data.verificationPassed=$true;$Run.Data.lastFailure=$null}
        else{
            $Run.Data.verificationPassed=$false;$Run.Data.lastFailure=$Failure
            $Run.Data.repairCycles=[int]$Run.Data.repairCycles+1
            Set-LsdaMicroState $Run 'REPAIR'
        }
    }
    Save-LsdaMicroRun $Run
    if([int]$Run.Data.toolCalls -ge [int]$Run.Data.limits.maxToolCalls){return 'tool-call budget exhausted'}
    if([int]$Run.Data.shellCalls -ge [int]$Run.Data.limits.maxShellCalls){return 'shell-call budget exhausted'}
    if([int]$Run.Data.repairCycles -gt [int]$Run.Data.limits.maxRepairCycles){return 'repair budget exhausted'}
    if($Run.SameActionRepeats -gt [int]$Run.Data.limits.maxSameActionRepeats){return 'identical action repeated without progress'}
    if($Run.NoProgressActions -ge [int]$Run.Data.limits.maxNoProgressActions){return 'no engineering progress'}
    return $null
}

function Test-LsdaMicroDone {
    param([Parameter(Mandatory)]$Run)
    if([string]$Run.Data.state -eq 'BLOCKED'){return [pscustomobject]@{Allowed=$false;Reason='run is already BLOCKED'}}
    if([bool]$Run.Data.readOnly){return [pscustomobject]@{Allowed=$true;Reason=$null}}
    if(-not [bool]$Run.Data.changed){return [pscustomobject]@{Allowed=$false;Reason='no repository write was recorded'}}
    if(-not [bool]$Run.Data.verificationPassed){return [pscustomobject]@{Allowed=$false;Reason='no successful shell verification was recorded after the change'}}
    return [pscustomobject]@{Allowed=$true;Reason=$null}
}

function Test-LsdaMicroBlocked {
    param([Parameter(Mandatory)]$Run)
    if([string]$Run.Data.state -eq 'REPAIR' -and [int]$Run.Data.repairCycles -le [int]$Run.Data.limits.maxRepairCycles -and [int]$Run.Data.turns -lt [int]$Run.Data.limits.maxTurns){
        return [pscustomobject]@{Allowed=$false;Reason='the latest verification failure is still repairable within the remaining budget'}
    }
    if([string]$Run.Data.state -eq 'IMPLEMENT' -and [bool]$Run.Data.changed -and -not [bool]$Run.Data.verificationPassed -and [int]$Run.Data.turns -lt [int]$Run.Data.limits.maxTurns){
        return [pscustomobject]@{Allowed=$false;Reason='repository changes still require verification or repair'}
    }
    return [pscustomobject]@{Allowed=$true;Reason=$null}
}

function Stop-LsdaMicroRun {
    param([Parameter(Mandatory)]$Run,[Parameter(Mandatory)][string]$Reason)
    $Run.Data.blocker=$Reason
    if([string]$Run.Data.state -notin @('DONE','BLOCKED')){Set-LsdaMicroState $Run 'BLOCKED'}else{Save-LsdaMicroRun $Run}
}
