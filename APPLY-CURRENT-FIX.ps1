[CmdletBinding()]
param(
  [string]$Root = 'C:\AI\local-coding-agent'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $Root -PathType Container)){
  throw "Local Coding Agent root not found: $Root"
}
$version=(Get-Content -LiteralPath (Join-Path $Root 'VERSION') -Raw).Trim()
if($version -ne '1.0.0-dev'){
  throw "Expected VERSION 1.0.0-dev, got '$version'."
}

$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backup=Join-Path $Root ("backup\test-contract-fix-$stamp")
New-Item -ItemType Directory -Force -Path $backup|Out-Null

$files=@(
 'tests\VERIFY-REGRESSION-HISTORY.ps1',
 'tests\VERIFY-NATIVE-STDERR.ps1',
 'tests\VERIFY-DEV-STRICTMODE-EXITCODE.ps1',
 'tests\VERIFY-RUN-CHANGE-ACCOUNTING.ps1'
)
foreach($rel in $files){
  $src=Join-Path $Root $rel
  if(-not(Test-Path -LiteralPath $src)){throw "Missing file: $src"}
  $dest=Join-Path $backup ([IO.Path]::GetFileName($rel))
  Copy-Item -LiteralPath $src -Destination $dest -Force
}

# 1) Historical regression: current capture architecture uses stderr.txt rather
# than ProcessStartInfo.RedirectStandardError.
$p=Join-Path $Root 'tests\VERIFY-REGRESSION-HISTORY.ps1'
$s=Get-Content -LiteralPath $p -Raw
$old="Need 'REG-014' 'native stderr warnings cannot abort managed workflow' ((`$module -match 'Test-AgentNonFatalNativeWarning') -and (`$module -match 'System.Diagnostics.ProcessStartInfo') -and (`$module -match 'RedirectStandardError') -and (Test-Path (Join-Path `$root 'tests\VERIFY-NATIVE-STDERR.ps1')))"
$new="Need 'REG-014' 'native stderr warnings cannot abort managed workflow' ((`$module -match 'Test-AgentNonFatalNativeWarning') -and (`$module -match 'stderr\.txt') -and (`$module -match 'native-warnings\.txt') -and (Test-Path (Join-Path `$root 'tests\VERIFY-NATIVE-STDERR.ps1')))"
if(-not $s.Contains($old)){throw 'Historical REG-014 old contract not found; refusing blind patch.'}
$s=$s.Replace($old,$new)
Set-Content -LiteralPath $p -Value $s -Encoding UTF8

# 2) DEV StrictMode verifier: use a single-quoted regex so $root is literal.
$p=Join-Path $Root 'tests\VERIFY-DEV-STRICTMODE-EXITCODE.ps1'
$s=Get-Content -LiteralPath $p -Raw
$old='if($dev -match "& \(Join-Path \$root ''VERIFY-PACKAGE\.ps1''\)\s*\r?\n\s*if\(\$LASTEXITCODE"){'
$new="if(`$dev -match '& \(Join-Path \`$root ''VERIFY-PACKAGE\.ps1''\)\s*\r?\n\s*if\(\`$LASTEXITCODE'){"
if(-not $s.Contains($old)){throw 'DEV StrictMode verifier old regex not found; refusing blind patch.'}
$s=$s.Replace($old,$new)
Set-Content -LiteralPath $p -Value $s -Encoding UTF8

# 3) Change-accounting verifier: use a single-quoted regex so
# $normallyChanges is not evaluated by the verifier itself.
$p=Join-Path $Root 'tests\VERIFY-RUN-CHANGE-ACCOUNTING.ps1'
$s=Get-Content -LiteralPath $p -Raw
$old='if($m -notmatch "elseif\(-not \$normallyChanges\)\{''FAIL''\}"){'
$new="if(`$m -notmatch 'elseif\(-not \`$normallyChanges\)\{''FAIL''\}'){"
if(-not $s.Contains($old)){throw 'Run-change-accounting old regex not found; refusing blind patch.'}
$s=$s.Replace($old,$new)
Set-Content -LiteralPath $p -Value $s -Encoding UTF8

# 4) Native stderr test: test the current warning classifier + current
# stderr-file separation contract, not the removed nested fake-process design.
$p=Join-Path $Root 'tests\VERIFY-NATIVE-STDERR.ps1'
@'
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
'@ | Set-Content -LiteralPath $p -Encoding UTF8

Write-Host "[PASS] Patched four Windows regression contracts in-place." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Next command:' -ForegroundColor Cyan
Write-Host '  .\DEV.ps1 install'
