[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$harness=Get-Content -LiteralPath (Join-Path $root 'tests\RUN-ALL.ps1') -Raw
$live=Get-Content -LiteralPath (Join-Path $root 'tests\RUN-LIVE-E2E.ps1') -Raw
if($harness.Contains("Join-Path `$root 'test-results'")){throw 'RUN-ALL still writes test-results into the candidate package.'}
if($live.Contains("Join-Path `$root 'test-results'")){throw 'RUN-LIVE-E2E still writes test-results into the candidate package.'}
if($harness -notmatch 'GetTempPath'){throw 'RUN-ALL is not isolated under TEMP.'}
if($live -notmatch 'GetTempPath'){throw 'RUN-LIVE-E2E is not isolated under TEMP.'}
Write-Host '[PASS] test output is isolated from package/project roots' -ForegroundColor Green
