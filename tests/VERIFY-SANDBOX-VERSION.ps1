[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$q=Get-Content -LiteralPath (Join-Path $root 'tests\sandbox\qualify.py') -Raw
if($q -match 'require\(v=="1\.0\.0-rc\.'){throw '[FAIL] sandbox qualifier hardcodes a release candidate version'}
if($q -notmatch 'VERSION is the source of truth'){throw '[FAIL] sandbox VERSION source-of-truth contract missing'}
if($q -notmatch 'TEST-MATRIX\.json'){throw '[FAIL] sandbox version consistency does not cover TEST-MATRIX'}
Write-Host '[PASS] sandbox qualifier derives candidate version from VERSION' -ForegroundColor Green
Write-Host 'Sandbox version contract PASS' -ForegroundColor Cyan
