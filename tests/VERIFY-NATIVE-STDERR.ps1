[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
$moduleText=Get-Content -LiteralPath $modulePath -Raw

try{
  Remove-Module LocalCodingAgent -Force -ErrorAction SilentlyContinue
  Import-Module $modulePath -Force -DisableNameChecking
  $m=Get-Module LocalCodingAgent | Where-Object {$_.Path -eq $modulePath} | Select-Object -First 1
  if(-not $m){throw 'LocalCodingAgent module was not imported.'}

  $warning="warning: in the working copy of 'docs/production-review.md', LF will be replaced by CRLF the next time Git touches it"
  $isWarning=& $m { param($line) Test-AgentNonFatalNativeWarning $line } $warning
  if(-not $isWarning){throw '[FAIL] known Git line-ending warning is not classified as non-fatal'}
  Write-Host '[PASS] Git line-ending stderr is classified as non-fatal' -ForegroundColor Green

  $realError='fatal: simulated native failure'
  $isWarning=& $m { param($line) Test-AgentNonFatalNativeWarning $line } $realError
  if($isWarning){throw '[FAIL] real native stderr was incorrectly classified as warning'}
  Write-Host '[PASS] real native stderr remains an error' -ForegroundColor Green

  $tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-native-stderr-'+[guid]::NewGuid().ToString('N'))
  try{
    New-Item -ItemType Directory -Force -Path $tmp|Out-Null
    git -C $tmp init --quiet
    git -C $tmp config user.name 'Local Coding Agent Test'
    git -C $tmp config user.email 'local-agent@localhost'
    git -C $tmp config core.autocrlf false
    "line`n"|Set-Content -LiteralPath (Join-Path $tmp 'sample.txt') -Encoding Ascii
    git -C $tmp add sample.txt
    git -C $tmp commit -m baseline --quiet
    git -C $tmp config core.autocrlf true
    [IO.File]::WriteAllText((Join-Path $tmp 'sample.txt'),"changed`n",(New-Object Text.UTF8Encoding($false)))
    $snapshot=& $m {param($p) Get-GitSnapshot $p} $tmp
    if(-not $snapshot.isGit -or @($snapshot.status).Count -lt 1){throw '[FAIL] dirty Git snapshot was not collected'}
    $fingerprint=& $m {param($p) Get-AgentWorkingTreeFingerprint $p} $tmp
    if([string]::IsNullOrWhiteSpace([string]$fingerprint)){throw '[FAIL] dirty working-tree fingerprint was not collected'}
    Write-Host '[PASS] dirty Git snapshot survives native LF/CRLF stderr under ErrorActionPreference Stop' -ForegroundColor Green
  }finally{
    if($tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
  }

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
