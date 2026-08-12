[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'powershell\MicroRuntime.ps1')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('lsda-micro-runtime-'+[guid]::NewGuid().ToString('N'))
try{
    New-Item -ItemType Directory -Force -Path $tmp|Out-Null
    $run=New-LsdaMicroRun -RepositoryRoot $root -RunDirectory $tmp -MaxTurns 3 -MaxToolCalls 5 -MaxShellCalls 2 -MaxRepairCycles 1 -MaxTokens 100
    if($run.Data.state -ne 'INVESTIGATE' -or -not(Test-Path (Join-Path $tmp 'run.json'))){throw '[FAIL] persistent run initialization'}
    $early=Test-LsdaMicroDone $run
    if($early.Allowed -or $early.Reason -notmatch 'repository write'){throw '[FAIL] false DONE accepted before write'}

    $block=Add-LsdaMicroAction -Run $run -Name 'write_file' -Signature 'write|a' -Succeeded $true -Changed $true -Path 'a.txt'
    if($block -or $run.Data.state -ne 'IMPLEMENT' -or -not $run.Data.changed){throw '[FAIL] write progress accounting'}
    $unverified=Test-LsdaMicroDone $run
    if($unverified.Allowed -or $unverified.Reason -notmatch 'verification'){throw '[FAIL] false DONE accepted before verification'}

    $block=Add-LsdaMicroAction -Run $run -Name 'shell' -Signature 'shell|test-fail' -Succeeded $false -Changed $false -Failure 'test failed' -IsVerification $true
    if($block -or $run.Data.state -ne 'REPAIR' -or $run.Data.repairCycles -ne 1){throw '[FAIL] repair transition/accounting'}
    $repairable=Test-LsdaMicroBlocked $run
    if($repairable.Allowed -or $repairable.Reason -notmatch 'repairable'){throw '[FAIL] repairable failure accepted as BLOCKED'}
    Add-LsdaMicroAction -Run $run -Name 'write_file' -Signature 'write|repair' -Succeeded $true -Changed $true|Out-Null
    Add-LsdaMicroAction -Run $run -Name 'shell' -Signature 'shell|test-pass' -Succeeded $true -Changed $false -IsVerification $true|Out-Null
    $done=Test-LsdaMicroDone $run
    if(-not $done.Allowed){throw "[FAIL] verified DONE rejected: $($done.Reason)"}
    Set-LsdaMicroState $run 'DONE'
    $saved=Get-Content (Join-Path $tmp 'run.json') -Raw|ConvertFrom-Json
    if($saved.state -ne 'DONE' -or -not $saved.verificationPassed -or $saved.writeCalls -ne 2){throw '[FAIL] final state persistence'}
    foreach($artifact in @('changes.json','verification.json','result.md')){if(-not(Test-Path (Join-Path $tmp $artifact))){throw "[FAIL] missing terminal artifact: $artifact"}}
    $changes=Get-Content (Join-Path $tmp 'changes.json') -Raw|ConvertFrom-Json
    if(@($changes.files) -notcontains 'a.txt'){throw '[FAIL] changed file evidence'}

    $lintDir=Join-Path $tmp 'lint-gate'
    $lintRun=New-LsdaMicroRun -RepositoryRoot $root -RunDirectory $lintDir -RequireLint
    Add-LsdaMicroAction -Run $lintRun -Name 'write_file' -Signature 'write|linted' -Succeeded $true -Changed $true|Out-Null
    Add-LsdaMicroAction -Run $lintRun -Name 'shell' -Signature 'shell|tests' -Succeeded $true -Changed $false -IsVerification $true|Out-Null
    $missingLint=Test-LsdaMicroDone $lintRun
    if($missingLint.Allowed -or $missingLint.Reason -notmatch 'lint'){throw '[FAIL] configured lint gate was not required'}
    Add-LsdaMicroAction -Run $lintRun -Name 'shell' -Signature 'shell|lint' -Succeeded $true -Changed $false -IsVerification $true -IsLint $true|Out-Null
    if(-not (Test-LsdaMicroDone $lintRun).Allowed -or -not $lintRun.Data.lintPassed -or $lintRun.Data.lintCalls -ne 1){throw '[FAIL] separate test/lint evidence did not allow DONE'}
    Add-LsdaMicroAction -Run $lintRun -Name 'write_file' -Signature 'write|after-lint' -Succeeded $true -Changed $true|Out-Null
    if($lintRun.Data.lintPassed -or $lintRun.Data.verificationPassed){throw '[FAIL] edit did not invalidate prior test/lint evidence'}

    $recoverDir=Join-Path $tmp 'recover'
    $interrupted=New-LsdaMicroRun -RepositoryRoot $root -RunDirectory $recoverDir
    Add-LsdaMicroAction -Run $interrupted -Name 'write_file' -Signature 'write|interrupted' -Succeeded $true -Changed $true|Out-Null
    $recovered=New-LsdaMicroRun -RepositoryRoot $root -RunDirectory $recoverDir
    if($recovered.Data.state -ne 'RECOVERING' -or -not $recovered.Data.changed){throw '[FAIL] interrupted run recovery'}
    Set-LsdaMicroState $recovered 'IMPLEMENT'

    $watchDir=Join-Path $tmp 'watchdog'
    $watch=New-LsdaMicroRun -RepositoryRoot $root -RunDirectory $watchDir -MaxSameActionRepeats 2 -MaxNoProgressActions 5
    Add-LsdaMicroAction -Run $watch -Name 'read_file' -Signature 'read|same' -Succeeded $true -Changed $false|Out-Null
    Add-LsdaMicroAction -Run $watch -Name 'read_file' -Signature 'read|same' -Succeeded $true -Changed $false|Out-Null
    $reason=Add-LsdaMicroAction -Run $watch -Name 'read_file' -Signature 'read|same' -Succeeded $true -Changed $false
    if($reason -notmatch 'identical action'){throw '[FAIL] repeated action watchdog'}

    $budgetDir=Join-Path $tmp 'budget'
    $budget=New-LsdaMicroRun -RepositoryRoot $root -RunDirectory $budgetDir -MaxTokens 10
    $reason=Add-LsdaMicroTurn -Run $budget -PromptTokens 8 -OutputTokens 3
    if($reason -notmatch 'token budget'){throw '[FAIL] token budget watchdog'}
}finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host '[PASS] micro runtime state, deterministic DONE, recovery and watchdogs' -ForegroundColor Green
