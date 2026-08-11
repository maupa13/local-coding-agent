[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$runAll=Join-Path $root 'tests\RUN-ALL.ps1'
$exe=(Get-Command powershell.exe -ErrorAction Stop).Source
& $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $runAll -Profile Full -HarnessSelfTest
if($LASTEXITCODE -ne 0){throw "RUN-ALL harness self-test failed with exit code $LASTEXITCODE"}
$text=Get-Content $runAll -Raw
foreach($needle in @('Get-TestLogPath','HarnessSelfTest','regression-HARNESS_SELF_TEST.log')){
 if($text -notmatch [regex]::Escape($needle)){throw "RUN-ALL missing harness contract: $needle"}
}
Write-Host 'RUN-ALL harness smoke PASS' -ForegroundColor Green
