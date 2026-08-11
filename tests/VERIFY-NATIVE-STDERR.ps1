[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
$moduleText=Get-Content -LiteralPath $modulePath -Raw

try{
  Import-Module $modulePath -Force -DisableNameChecking
  $m=Get-Module LocalCodingAgent | Select-Object -First 1
  if(-not $m){throw 'LocalCodingAgent module was not imported.'}

  $warning="warning: in the working copy of 'docs/production-review.md', LF will be replaced by CRLF the next time Git touches it"
  $isWarning=& $m { param($line) Test-AgentNonFatalNativeWarning $line } $warning
  if(-not $isWarning){throw '[FAIL] known Git line-ending warning is not classified as non-fatal'}
  Write-Host '[PASS] Git line-ending stderr is classified as non-fatal' -ForegroundColor Green

  $realError='fatal: simulated native failure'
  $isWarning=& $m { param($line) Test-AgentNonFatalNativeWarning $line } $realError
  if($isWarning){throw '[FAIL] real native stderr was incorrectly classified as warning'}
  Write-Host '[PASS] real native stderr remains an error' -ForegroundColor Green

  foreach($needle in @('stderr.txt','native-warnings.txt','native-stderr.txt','Test-AgentNonFatalNativeWarning')){
    if($moduleText -notmatch [regex]::Escape($needle)){throw "[FAIL] managed capture contract missing: $needle"}
  }
  if($moduleText -notmatch 'foreach\(\$raw in @\(\$stderr -split'){
    throw '[FAIL] managed capture does not process captured stderr line-by-line'
  }
  Write-Host '[PASS] managed capture persists and separates warning/error stderr evidence' -ForegroundColor Green
  Write-Host 'Native stderr warning isolation PASS' -ForegroundColor Cyan
}finally{
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
}
