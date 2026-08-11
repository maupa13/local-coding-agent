[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$qualify=Get-Content -LiteralPath (Join-Path $root 'QUALIFY-RELEASE.ps1') -Raw
$install=Get-Content -LiteralPath (Join-Path $root 'INSTALL.ps1') -Raw

if($version -ne '1.0.0-dev'){throw "[FAIL] development workspace VERSION is '$version'"}
if($qualify -match 'Package folder/version mismatch'){throw '[FAIL] qualification still requires versioned source folder'}
if($install -match 'Package folder/version mismatch'){throw '[FAIL] installer still requires versioned source folder'}
Write-Host '[PASS] stable development workspace is version-folder independent' -ForegroundColor Green
Write-Host 'Development workspace contract PASS' -ForegroundColor Cyan
