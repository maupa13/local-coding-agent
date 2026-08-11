[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
$text=Get-Content -LiteralPath $modulePath -Raw

function Need([string]$Pattern,[string]$Name){
  if($text -notmatch $Pattern){throw "[FAIL] $Name"}
  Write-Host "[PASS] $Name" -ForegroundColor Green
}

Need '\[AllowEmptyString\(\)\]\[string\]\$PreviousOutput' 'compliance recovery accepts empty first-pass output'
Need 'model output was empty; semantic result NOT CAPTURED' 'empty managed output is not reported as semantic PASS'
Need 'capture-diagnostic\.txt' 'empty capture diagnostic evidence'
Need 'process completion is not task success' 'runner summary separates process and task success'
Need '\[NO MODEL OUTPUT WAS CAPTURED FROM THE FIRST PASS' 'compliance recovery has deterministic empty-output context'
Write-Host 'Empty capture recovery contract PASS' -ForegroundColor Green
