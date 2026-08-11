[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
foreach($cfg in @('config.yaml','config-agent.yaml','config-agent-fast.yaml')){
  $path=Join-Path $root "config\$cfg"
  $size=(Get-Item $path).Length
  if($size -gt 65000){ throw "$cfg too large: $size bytes" }
  $text=Get-Content $path -Raw
  $count=([regex]::Matches($text,'MANDATORY FINAL RESULT')).Count
  if($count -ne 1){ throw "$cfg repeats global final contract $count times" }
  Write-Host "[PASS] $cfg context budget: $size bytes"
}
$workflows=Get-ChildItem (Join-Path $root 'workflows') -Filter '*.md' -File | Where-Object Name -ne 'workflows.md'
foreach($wf in $workflows){
  $text=Get-Content $wf.FullName -Raw
  if($text -notmatch 'ACTIVE WORKFLOW:'){ throw "$($wf.Name) missing workflow lock" }
  if($text -match '## Execution reliability contract'){ throw "$($wf.Name) still duplicates reliability contract" }
}
Write-Host '[PASS] workflow lock/compactness'
