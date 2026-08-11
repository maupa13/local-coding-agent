[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
$module=Get-Content -LiteralPath $modulePath -Raw

$safe="TrimStart([char]'\',[char]'/')"
if(-not $module.Contains($safe)){
  throw "[FAIL] filesystem inventory does not use PS5.1-safe explicit separator chars."
}

# Verify the exact character sequence in the inventory expression: quote,
# ONE backslash, quote. This catches the previous '\\' two-character defect.
$line=($module -split "`r?`n" | Where-Object {$_ -match 'FullName\.Substring\(\$RepositoryRoot\.Length\)\.TrimStart'} | Select-Object -Last 1)
if(-not $line){throw '[FAIL] inventory TrimStart line not found'}
$backslashCount=0
$segment=($line -split 'TrimStart',2)[1]
foreach($c in $segment.ToCharArray()){if([int][char]$c -eq 92){$backslashCount++}}
if($backslashCount -ne 1){
  throw "[FAIL] expected exactly one backslash character in inventory TrimStart expression, got $backslashCount"
}

Write-Host '[PASS] inventory TrimStart contains exactly one backslash char and one slash char' -ForegroundColor Green
Write-Host 'PS5.1 path-char regression PASS' -ForegroundColor Cyan
