[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$m=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

foreach($needle in @(
  "stage='init'",
  "stage='docs-root'",
  "stage='direct-discovery'",
  "stage='inventory'",
  "stage='candidate-merge'",
  "stage='dedupe'",
  "FATAL:",
  "Position:"
)){
  if($m -notmatch [regex]::Escape($needle)){throw "[FAIL] extractor diagnostic stage missing: $needle"}
}
if($m -match 'TrimStart\(\[char\[\]\]'){
  throw '[FAIL] extractor still uses PS5.1-sensitive TrimStart(char[]) binder path'
}
Write-Host '[PASS] staged extractor diagnostics and PS5.1-safe path normalization' -ForegroundColor Green
Write-Host 'Extractor staged diagnostics regression PASS' -ForegroundColor Cyan
