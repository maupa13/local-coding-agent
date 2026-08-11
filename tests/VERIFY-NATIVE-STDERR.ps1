[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
$temp=Join-Path $env:TEMP ('lca-native-stderr-'+[guid]::NewGuid().ToString('N'))
$bin=Join-Path $temp 'bin'
$repo=Join-Path $temp 'repo'
New-Item -ItemType Directory -Force -Path $bin,$repo|Out-Null
$fake=Join-Path $bin 'cn.cmd'
@'
@echo off
echo warning: in the working copy of 'docs/production-review.md', LF will be replaced by CRLF the next time Git touches it 1>&2
echo FINAL RESULT: PASS
echo WORKFLOW: analysis
exit /b 0
'@ | Set-Content -Encoding ASCII $fake
$oldPath=$env:PATH
try{
  $env:PATH=$bin+';'+$oldPath
  Import-Module $modulePath -Force -DisableNameChecking
  $m=Get-Module LocalCodingAgent | Select-Object -First 1
  if(-not $m){throw 'LocalCodingAgent module was not imported.'}
  $out=Join-Path $temp 'model-output.txt'
  $result=& $m { param($r,$o) Invoke-CnCaptured -RepositoryRoot $r -Arguments @('--fake') -OutputPath $o } $repo $out
  if($result.ExitCode -ne 0){throw "Fake cn should exit 0, got $($result.ExitCode)."}
  if($result.Output -notmatch 'FINAL RESULT:\s*PASS'){throw ('stdout was not captured. Actual output: ' + $result.Output)}
  $diskOutput = if(Test-Path $out){Get-Content -LiteralPath $out -Raw}else{''}
  if($diskOutput -notmatch 'FINAL RESULT:\s*PASS'){throw ('stdout evidence was not captured. File content: ' + $diskOutput)}
  if(@($result.NativeWarnings).Count -ne 1){throw "Expected one non-fatal native warning, got $(@($result.NativeWarnings).Count)."}
  $warnFile=Join-Path $temp 'native-warnings.txt'
  if(-not(Test-Path $warnFile)){throw 'native-warnings.txt was not created.'}
  Write-Host '[PASS] native stderr warning does not abort managed capture' -ForegroundColor Green
}finally{
  $env:PATH=$oldPath
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
