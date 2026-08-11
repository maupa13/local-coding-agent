[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$modulePath=Join-Path $root 'powershell\LocalCodingAgent.psm1'
Import-Module $modulePath -Force -DisableNameChecking
$m=Get-Module LocalCodingAgent | Select-Object -First 1
if(-not $m){throw '[FAIL] module import failed'}
$tmp=$null
try{
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ('lca-nongit-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  Set-Content -LiteralPath (Join-Path $tmp 'main.md') -Encoding UTF8 -Value '# draft'
  $snap=& $m { param($p) Get-GitSnapshot $p } $tmp
  if($snap.isGit){throw '[FAIL] plain temp folder was incorrectly treated as git'}
  $inv=& $m { param($p) Get-AgentRepositoryInventory $p } $tmp
  if(@($inv.Docs) -notcontains 'main.md'){throw '[FAIL] non-git root main.md is not discovered as documentation'}
  Write-Host '[PASS] non-git folder does not invoke git workflow and main.md is discovered' -ForegroundColor Green
}finally{
  if($tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
  Remove-Module LocalCodingAgent -ErrorAction SilentlyContinue
}
Write-Host 'Non-git inventory regression PASS' -ForegroundColor Cyan
