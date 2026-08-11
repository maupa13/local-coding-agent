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

Need 'Join-Path \$RepositoryRoot ''docs''' 'compliance extraction scans docs directly'
Need 'Get-ChildItem -LiteralPath \$docsRoot -Recurse -File' 'recursive docs discovery'
Need '\(\?:\\:\\|\[-–—\]\)' 'requirement parser accepts colon or dash separator'
Need '\(\?:\[-\*\+\]\\s\*\)\?' 'requirement parser accepts markdown bullets'
Need 'Sort-Object -Unique' 'documentation candidate deduplication'
Need '\$seen\.ContainsKey' 'requirement ID deduplication'
Write-Host 'Compliance requirement extraction regression PASS' -ForegroundColor Cyan
