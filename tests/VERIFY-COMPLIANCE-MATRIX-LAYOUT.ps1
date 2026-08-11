[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$module=Get-Content -LiteralPath (Join-Path $root 'powershell\LocalCodingAgent.psm1') -Raw

function Need([string]$Pattern,[string]$Name){
  if($module -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

Need '\$matrixMatch=\[regex\]::Match\(\$Text' 'compliance matrix is validated from complete model output'
Need '\(\?=\\s\*FINAL RESULT:\)' 'matrix block is bounded by terminal FINAL RESULT'
Need '\|\s*\(\?:REQ\|Requirement\)' 'matrix must have requirement table evidence'
Need 'REQ\[-_ \]\?\\d\+' 'matrix must contain requirement identifiers'
Need '\$status=Get-FinalResultStatus \$report' 'semantic status still comes from terminal report'
Write-Host 'Compliance matrix layout regression PASS' -ForegroundColor Cyan
