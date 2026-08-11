[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw
foreach($needle in @(
  'System.Text.UTF8Encoding',
  'Console]::OutputEncoding',
  'PYTHONIOENCODING',
  'stdout.txt',
  'stderr.txt'
)){
  if($module -notmatch [regex]::Escape($needle)){throw "[FAIL] UTF-8 capture contract missing: $needle"}
  Write-Host "[PASS] UTF-8 capture: $needle" -ForegroundColor Green
}
Write-Host 'UTF-8 process capture contract PASS' -ForegroundColor Cyan
