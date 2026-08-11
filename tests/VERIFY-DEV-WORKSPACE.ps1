[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$qualify=Get-Content -LiteralPath (Join-Path $root 'powershell\QUALIFY-RELEASE.ps1') -Raw
$install=Get-Content -LiteralPath (Join-Path $root 'powershell\INSTALL.ps1') -Raw

if($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$'){throw "[FAIL] development workspace VERSION is invalid: '$version'"}
if($qualify -match 'Package folder/version mismatch'){throw '[FAIL] qualification still requires versioned source folder'}
if($install -match 'Package folder/version mismatch'){throw '[FAIL] installer still requires versioned source folder'}
Write-Host '[PASS] stable development workspace is version-folder independent' -ForegroundColor Green
Write-Host 'Development workspace contract PASS' -ForegroundColor Cyan
