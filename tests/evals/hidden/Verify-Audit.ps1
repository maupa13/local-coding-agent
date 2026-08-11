param([Parameter(Mandatory)][string]$Project)
$audit=Join-Path $Project 'AUDIT.md'
if(-not(Test-Path -LiteralPath $audit)){throw 'AUDIT.md was not created'}
$text=Get-Content -LiteralPath $audit -Raw
foreach($required in @('Invoke-UnsafeDelete','-WhatIf','path traversal','Write-Host','REQ-PS-01','REQ-PS-02','REQ-PS-03','NOT COMPLIANT')){
  if($text -notmatch [regex]::Escape($required)){throw "AUDIT.md misses independently known finding: $required"}
}
if($text -notmatch '(?i)Tools\.psm1.+:\d+' ){throw 'AUDIT.md lacks file/line evidence'}
Write-Host '[PASS] hidden PowerShell analysis/document oracle'
